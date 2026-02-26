function Test-YarboConnection {
    <#
.SYNOPSIS
    Tests whether a Yarbo MQTT connection is active and healthy.

.DESCRIPTION
    Checks the MQTT client state, last heartbeat age, and broker reachability.

.PARAMETER Connection
    The connection to test. Defaults to the current default.

.PARAMETER Detailed
    Returns a PSCustomObject with detailed connection info instead of a boolean.

.EXAMPLE
    Test-YarboConnection

.EXAMPLE
    Test-YarboConnection -Detailed

.LINK
    Connect-Yarbo
#>
    [CmdletBinding()]
    [OutputType([bool], [PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter()]
        [switch]$Detailed
    )

    process {
        try {
            $conn = Resolve-YarboConnection -Connection $Connection
        } catch {
            if ($Detailed) {
                return [PSCustomObject]@{
                    Connected          = $false
                    Broker             = $null
                    SerialNumber       = $null
                    State              = 'Disconnected'
                    LastHeartbeat      = $null
                    HeartbeatAge       = $null
                    ControllerAcquired = $false
                }
            }
            return $false
        }

        $connected = $conn.MqttClient -and $conn.MqttClient.IsConnected
        $heartbeatAge = if ($conn.LastHeartbeat -ne [datetime]::MinValue) {
            [datetime]::UtcNow - $conn.LastHeartbeat
        } else { $null }

        if ($Detailed) {
            return [PSCustomObject]@{
                Connected          = $connected
                Broker             = $conn.Broker
                SerialNumber       = $conn.SerialNumber
                State              = $conn.State.ToString()
                LastHeartbeat      = $conn.LastHeartbeat
                HeartbeatAge       = $heartbeatAge
                ControllerAcquired = $conn.ControllerAcquired
                ClientId           = $conn.ClientId
                ConnectedAt        = $conn.ConnectedAt
            }
        }

        return $connected
    }
}
