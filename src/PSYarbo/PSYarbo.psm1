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

#region — Load MQTTnet and C# listener helper
$libPath = Join-Path $PSScriptRoot 'lib'
$mqttDllPath = Join-Path $libPath 'MQTTnet.dll'

if (Test-Path $mqttDllPath) {
    $script:MqttAssembly = [System.Reflection.Assembly]::LoadFrom((Resolve-Path $mqttDllPath).Path)
    Write-Verbose "PSYarbo: Loaded MQTTnet from $mqttDllPath"
    # C# helper: connects, subscribes, and receives messages entirely in C# so the MQTTnet
    # ApplicationMessageReceivedAsync event is attached with += and always fires.
    $listenerCode = @'
using System;
using System.Collections;
using System.Threading;
using System.Threading.Tasks;

namespace PSYarbo.Mqtt {
    public sealed class YarboMqttListener : IDisposable {
        private readonly MQTTnet.MqttFactory _factory;
        private MQTTnet.Client.IMqttClient _client;
        private readonly ArrayList _messages = ArrayList.Synchronized(new ArrayList());
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
                _messages.Add(msg);
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
            var arr = new ReceivedMessage[_messages.Count];
            _messages.CopyTo(arr);
            _messages.Clear();
            return arr;
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
using System.Collections.Generic;
using System.Threading.Tasks;
namespace PSYarbo.Mqtt {
    public static class MessageReceivedAdapter {
        private static readonly Dictionary<object, System.Func<object, Task>> _callbacks = new Dictionary<object, System.Func<object, Task>>();
        public static void RegisterCallback(object client, System.Func<object, Task> callback) {
            lock (_callbacks) {
                _callbacks[client] = callback;
            }
        }
        public static void UnregisterCallback(object client) {
            lock (_callbacks) {
                _callbacks.Remove(client);
            }
        }
        public static Task Handler(object sender, MQTTnet.Client.MqttApplicationMessageReceivedEventArgs ea) {
            System.Func<object, Task> callback = null;
            lock (_callbacks) {
                _callbacks.TryGetValue(sender, out callback);
            }
            if (callback != null) return callback(ea);
            return Task.CompletedTask;
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
