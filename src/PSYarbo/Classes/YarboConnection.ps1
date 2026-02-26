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

    YarboConnection() {
        $this.ResponseQueue = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
        $this.CommandLog = [System.Collections.Generic.List[PSCustomObject]]::new()
        $this.CancellationSource = [System.Threading.CancellationTokenSource]::new()
        $this.CommandSemaphore = [System.Threading.SemaphoreSlim]::new(1, 1)
    }

    [string] ToString() { return "Yarbo[$($this.SerialNumber)@$($this.Broker):$($this.Port)]" }
}
