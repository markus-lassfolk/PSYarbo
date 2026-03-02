enum MqttConnectionState {
    Disconnected
    Connecting
    Connected
    ControllerAcquired
}

class YarboConnection {
    [string]$Broker
    [int]$Port
    [string]$SerialNumber
    [string]$ClientId
    [MqttConnectionState]$State = [MqttConnectionState]::Disconnected
    [datetime]$ConnectedAt
    [datetime]$LastHeartbeat
    [int]$LastWorkingState
    [YarboRobot]$Robot
    [bool]$ControllerAcquired

    # Push-message feedback (populated by Connect-Yarbo message handler)
    [PSCustomObject]$LastPlanFeedback
    [PSCustomObject]$LastRechargeFeedback

    # Internal (hidden from default display)
    hidden [object]$MqttClient
    hidden [object]$MqttFactory
    hidden [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]$ResponseQueue
    hidden [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]$CommandLog
    hidden [System.Threading.CancellationTokenSource]$CancellationSource
    hidden [System.Threading.SemaphoreSlim]$CommandSemaphore
    # Signal released each time a response is enqueued; eliminates busy-wait
    hidden [System.Threading.SemaphoreSlim]$ResponseSignal
    # Event-driven telemetry queue for Watch-YarboTelemetry (tagged PSCustomObjects)
    [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]$TelemetryQueue
    # Signal released whenever an event is added to TelemetryQueue
    hidden [System.Threading.SemaphoreSlim]$TelemetrySignal
    # Bounded log of recent push-telemetry events (DeviceMSG, heartbeat, feedback)
    [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]$TelemetryLog

    YarboConnection() {
        $this.ResponseQueue = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
        $this.CommandLog = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
        $this.CancellationSource = [System.Threading.CancellationTokenSource]::new()
        $this.CommandSemaphore = [System.Threading.SemaphoreSlim]::new(1, 1)
        $this.ResponseSignal = [System.Threading.SemaphoreSlim]::new(0, [int]::MaxValue)
        $this.TelemetryQueue = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
        $this.TelemetrySignal = [System.Threading.SemaphoreSlim]::new(0, [int]::MaxValue)
        $this.TelemetryLog = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
    }

    # ── Delegate helpers ────────────────────────────────────────────────────────

    <#
    .SYNOPSIS
        Ensures the controller has been acquired for this session.
        Delegates to Assert-YarboController (private function).
    #>
    [void] EnsureController() {
        Assert-YarboController -Connection $this
    }

    <#
    .SYNOPSIS
        Sends an MQTT command and returns the result. Delegates to Send-MqttCommand.
    .PARAMETER Command
        Command name (e.g. 'get_device_msg').
    .PARAMETER Payload
        Optional hashtable of command parameters.
    .PARAMETER TimeoutMs
        How long to wait for a response (ms). Default 5000.
    .PARAMETER ThrowOnTimeout
        Throw YarboTimeoutException on timeout instead of returning a timed-out marker.
    #>
    [YarboCommandResult] SendCommand([string]$Command, [hashtable]$Payload, [int]$TimeoutMs, [bool]$ThrowOnTimeout) {
        return Send-MqttCommand -Connection $this -Command $Command -Payload $Payload `
            -TimeoutMs $TimeoutMs -ThrowOnTimeout:$ThrowOnTimeout
    }

    [YarboCommandResult] SendCommand([string]$Command, [hashtable]$Payload) {
        return Send-MqttCommand -Connection $this -Command $Command -Payload $Payload
    }

    [YarboCommandResult] SendCommand([string]$Command) {
        return Send-MqttCommand -Connection $this -Command $Command -Payload @{}
    }

    [string] ToString() { return "Yarbo[$($this.SerialNumber)@$($this.Broker):$($this.Port)]" }

    # Implement IDisposable — dispose all owned IDisposable members.
    # Disconnect-Yarbo calls this indirectly; classes holding a YarboConnection can also call it directly.
    # Resolve adapter type at runtime so the class can load when ScriptsToProcess runs before the .psm1 defines it.
    [void] Dispose() {
        try {
            if ($null -ne $this.MqttClient) {
                $adapterType = [System.AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType('PSYarbo.Mqtt.MessageReceivedAdapter') } | Where-Object { $_ } | Select-Object -First 1
                if ($null -ne $adapterType) {
                    $handlerDelegate = $adapterType.GetMethod('GetHandler').Invoke($null, @($this.MqttClient))
                    if ($null -ne $handlerDelegate) {
                        $this.MqttClient.GetType().GetMethod('remove_ApplicationMessageReceivedAsync').Invoke($this.MqttClient, @($handlerDelegate)) | Out-Null
                    }
                    $adapterType.GetMethod('UnregisterCallback').Invoke($null, @($this.MqttClient))
                }
            }
        } catch { $null = $_ }
        try { if ($null -ne $this.CancellationSource) { $this.CancellationSource.Dispose() } } catch { $null = $_ }
        try { if ($null -ne $this.CommandSemaphore) { $this.CommandSemaphore.Dispose() } } catch { $null = $_ }
        try { if ($null -ne $this.ResponseSignal) { $this.ResponseSignal.Dispose() } } catch { $null = $_ }
        try { if ($null -ne $this.TelemetrySignal) { $this.TelemetrySignal.Dispose() } } catch { $null = $_ }
        try {
            if ($null -ne $this.MqttClient -and $this.MqttClient -is [System.IDisposable]) {
                $this.MqttClient.Dispose()
            }
        } catch { $null = $_ }
        $this.CancellationSource = $null
        $this.CommandSemaphore = $null
        $this.ResponseSignal = $null
        $this.TelemetrySignal = $null
        $this.MqttClient = $null
    }
}
