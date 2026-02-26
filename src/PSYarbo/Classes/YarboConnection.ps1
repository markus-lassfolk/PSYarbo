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

    # Internal (hidden from default display)
    hidden [object]$MqttClient
    hidden [object]$MqttFactory
    hidden [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]$ResponseQueue
    hidden [System.Collections.Generic.List[PSCustomObject]]$CommandLog
    hidden [System.Threading.CancellationTokenSource]$CancellationSource
    hidden [System.Threading.SemaphoreSlim]$CommandSemaphore
    # Signal released each time a response is enqueued; eliminates busy-wait
    hidden [System.Threading.SemaphoreSlim]$ResponseSignal

    YarboConnection() {
        $this.ResponseQueue     = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
        $this.CommandLog        = [System.Collections.Generic.List[PSCustomObject]]::new()
        $this.CancellationSource = [System.Threading.CancellationTokenSource]::new()
        $this.CommandSemaphore  = [System.Threading.SemaphoreSlim]::new(1, 1)
        $this.ResponseSignal    = [System.Threading.SemaphoreSlim]::new(0, [int]::MaxValue)
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
}
