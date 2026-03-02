#Requires -Version 7.4
<#
.SYNOPSIS
    PSYarbo — PowerShell module for controlling Yarbo robot mowers via local MQTT and cloud REST API.

.DESCRIPTION
    Provides cmdlets to discover, connect to, and control Yarbo robot mowers
    on a local network using MQTT, and via cloud REST API for account management.

.NOTES
    Author:  Markus Lassfolk
    Project: https://github.com/markus-lassfolk/PSYarbo
    License: MIT
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region — Load MQTTnet and C# listener helper via isolated AssemblyLoadContext
$libPath = Join-Path $PSScriptRoot 'lib'
$mqttDllPath = Join-Path $libPath 'MQTTnet.dll'

if (Test-Path $mqttDllPath) {
    # Load MQTTnet into isolated ALC to avoid version conflicts with other modules
    $alcName = 'PSYarboMqttContext'
    $script:MqttALC = [System.Runtime.Loader.AssemblyLoadContext]::new($alcName, $true)
    $script:MqttAssembly = $script:MqttALC.LoadFromAssemblyPath((Resolve-Path $mqttDllPath).Path)
    Write-Verbose "PSYarbo: Loaded MQTTnet via isolated AssemblyLoadContext '$alcName'"
    
    # Set up assembly resolution so Add-Type can find MQTTnet from the isolated ALC
    $defaultALC = [System.Runtime.Loader.AssemblyLoadContext]::Default
    $resolvingHandler = [System.Func[System.Runtime.Loader.AssemblyLoadContext, System.Reflection.AssemblyName, System.Reflection.Assembly]] {
        param($context, $assemblyName)
        if ($assemblyName.Name -eq 'MQTTnet') {
            return $script:MqttAssembly
        }
        return $null
    }
    $defaultALC.add_Resolving($resolvingHandler)
    $script:MqttResolvingHandler = $resolvingHandler
    
    # C# helper: connects, subscribes, and receives messages entirely in C# so the MQTTnet
    # ApplicationMessageReceivedAsync event is attached with += and always fires.
    $listenerCode = @'
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace PSYarbo.Mqtt {
    public sealed class YarboMqttListener : IDisposable {
        private readonly MQTTnet.MqttFactory _factory;
        private MQTTnet.Client.IMqttClient _client;
        private readonly object _msgLock = new object();
        private readonly List<ReceivedMessage> _messages = new List<ReceivedMessage>();
        private readonly TaskCompletionSource<ReceivedMessage> _firstMessage = new TaskCompletionSource<ReceivedMessage>(TaskCreationOptions.RunContinuationsAsynchronously);

        public YarboMqttListener() {
            _factory = new MQTTnet.MqttFactory();
            _client = _factory.CreateMqttClient();
            _client.ApplicationMessageReceivedAsync += e => {
                var seg = e.ApplicationMessage.PayloadSegment;
                int len = seg.Array != null ? seg.Count : 0;
                byte[] copy = len > 0 ? new byte[len] : Array.Empty<byte>();
                if (len > 0 && seg.Array != null)
                    Buffer.BlockCopy(seg.Array, seg.Offset, copy, 0, len);
                var msg = new ReceivedMessage(e.ApplicationMessage.Topic ?? "", copy);
                lock (_msgLock) { _messages.Add(msg); }
                if (!_firstMessage.Task.IsCompleted)
                    _firstMessage.TrySetResult(msg);
                return Task.CompletedTask;
            };
        }

        public void Connect(string broker, int port, string clientId, TimeSpan timeout) {
            var opts = _factory.CreateClientOptionsBuilder()
                .WithTcpServer(broker, port)
                .WithClientId(clientId)
                .WithTimeout(timeout)
                .Build();
            _client.ConnectAsync(opts, CancellationToken.None).GetAwaiter().GetResult();
        }

        public void Subscribe(string[] topicFilters) {
            var builder = _factory.CreateSubscribeOptionsBuilder();
            foreach (var topic in topicFilters)
                builder = builder.WithTopicFilter(topic);
            var opts = builder.Build();
            _client.SubscribeAsync(opts, CancellationToken.None).GetAwaiter().GetResult();
        }

        public void Publish(string topic, byte[] payload) {
            var msg = _factory.CreateApplicationMessageBuilder()
                .WithTopic(topic)
                .WithPayload(payload ?? Array.Empty<byte>())
                .WithQualityOfServiceLevel(MQTTnet.Protocol.MqttQualityOfServiceLevel.AtMostOnce)
                .Build();
            _client.PublishAsync(msg, CancellationToken.None).GetAwaiter().GetResult();
        }

        public ReceivedMessage WaitForFirstMessage(int timeoutMs) {
            try {
                if (_firstMessage.Task.IsCompleted)
                    return _firstMessage.Task.Result;
                return _firstMessage.Task.Wait(timeoutMs) ? _firstMessage.Task.Result : null;
            } catch { return null; }
        }

        public ReceivedMessage[] GetReceivedMessages() {
            lock (_msgLock) {
                var arr = _messages.ToArray();
                _messages.Clear();
                return arr;
            }
        }

        public void Disconnect() {
            try {
                _client.DisconnectAsync(_factory.CreateClientDisconnectOptionsBuilder().Build(), CancellationToken.None).GetAwaiter().GetResult();
            } catch { }
        }

        public void Dispose() {
            Disconnect();
            _client?.Dispose();
            _client = null;
        }

        public sealed class ReceivedMessage {
            public string Topic { get; }
            public byte[] Payload { get; }
            public ReceivedMessage(string topic, byte[] payload) { Topic = topic; Payload = payload ?? Array.Empty<byte>(); }
        }
    }
}
'@
    try {
        $runtimeDir = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
        $refAssemblies = @($script:MqttAssembly)
        foreach ($name in @('netstandard.dll', 'System.Runtime.dll', 'System.Net.Primitives.dll')) {
            $path = Join-Path $runtimeDir $name
            if (Test-Path $path) {
                $refAssemblies += [System.Reflection.Assembly]::LoadFrom((Resolve-Path $path).Path)
            }
        }
        Add-Type -ReferencedAssemblies $refAssemblies -TypeDefinition $listenerCode -ErrorAction Stop
        Write-Verbose "PSYarbo: YarboMqttListener loaded"
    } catch {
        if ($_.Exception.Message -notmatch 'already exists') {
            Write-Verbose "PSYarbo: YarboMqttListener failed to load: $($_.Exception.Message)"
        }
    }
    # Legacy adapter (kept for Connect-Yarbo / Send-MqttCommand response path if still used)
    $adapterCode = @'
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
namespace PSYarbo.Mqtt {
    public static class MessageReceivedAdapter {
        private static readonly ConditionalWeakTable<object, CallbackEntry> _callbacks = new ConditionalWeakTable<object, CallbackEntry>();
        public static void RegisterCallback(object client, System.Func<object, Task> callback) {
            var entry = new CallbackEntry(callback);
            _callbacks.AddOrUpdate(client, entry);
        }
        public static void UnregisterCallback(object client) {
            _callbacks.Remove(client);
        }
        public static System.Func<MQTTnet.Client.MqttApplicationMessageReceivedEventArgs, Task> GetHandler(object client) {
            CallbackEntry entry;
            if (_callbacks.TryGetValue(client, out entry)) {
                return entry.Handler;
            }
            return null;
        }
        private sealed class CallbackEntry {
            public System.Func<object, Task> Callback { get; }
            public System.Func<MQTTnet.Client.MqttApplicationMessageReceivedEventArgs, Task> Handler { get; }
            public CallbackEntry(System.Func<object, Task> callback) {
                Callback = callback;
                Handler = ea => {
                    if (Callback != null) return Callback(ea);
                    return Task.CompletedTask;
                };
            }
        }
    }
}
'@
    try {
        Add-Type -ReferencedAssemblies $script:MqttAssembly -TypeDefinition $adapterCode -ErrorAction Stop
    } catch {
        Write-Verbose "PSYarbo: MessageReceivedAdapter already loaded or failed: $_"
    }
} else {
    $script:MqttAssembly = $null
    $script:MqttResolvingHandler = $null
    Write-Warning "MQTTnet.dll not found at '$mqttDllPath'. MQTT cmdlets will not work. Run build/Install-Dependencies.ps1 to download it."
}
#endregion

# Load classes if not already defined (e.g. when module is loaded via "using module" or in Pester;
# ScriptsToProcess runs for Import-Module and defines types in caller scope before root module runs).
$classFiles = @(
    'YarboExceptions', 'YarboLightState', 'YarboCommandResult',
    'YarboTelemetry', 'YarboPlan', 'YarboSchedule', 'YarboRobot',
    'YarboGlobalParams', 'YarboEndpoint', 'YarboConnection', 'YarboCloudSession'
)
if (-not ('YarboConnection' -as [type])) {
    foreach ($class in $classFiles) {
        . (Join-Path $PSScriptRoot "Classes/$class.ps1")
    }
}

#region — Load private functions
Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -Recurse | ForEach-Object {
    . $_.FullName
}
#endregion

#region — Load public functions
Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -Recurse | ForEach-Object {
    . $_.FullName
}
#endregion

# Load type data with -Force so re-import (Import-Module -Force) overwrites existing definitions
$typesPath = Join-Path $PSScriptRoot 'PSYarbo.Types.ps1xml'
if (Test-Path $typesPath) {
    try {
        Update-TypeData -Path $typesPath -Force -ErrorAction Stop
    } catch {
        Write-Verbose "PSYarbo: Could not load type data: $($_.Exception.Message)"
    }
}

#region — Module-scoped state
$script:YarboConnections = [System.Collections.Generic.Dictionary`2[System.String, YarboConnection]]::new()
$script:YarboCloudSession = $null
$script:DefaultConnection = $null
#endregion

$script:ModuleVersion = (Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'PSYarbo.psd1')).ModuleVersion
Write-Verbose "PSYarbo module loaded. Version: $script:ModuleVersion"

# Register cleanup handler to remove ALC resolving handler on module removal
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    if ($script:MqttResolvingHandler) {
        $defaultALC = [System.Runtime.Loader.AssemblyLoadContext]::Default
        $defaultALC.remove_Resolving($script:MqttResolvingHandler)
        $script:MqttResolvingHandler = $null
    }
}
