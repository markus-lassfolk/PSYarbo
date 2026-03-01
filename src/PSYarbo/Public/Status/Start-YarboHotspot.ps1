function Start-YarboHotspot {
    <#
.SYNOPSIS
    Starts the robot's Wi-Fi hotspot.

.DESCRIPTION
    Sends start_hotspot to enable the robot's built-in Wi-Fi access point,
    allowing direct wireless connections to the robot.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Start-YarboHotspot

.LINK
    Get-YarboWifiList
    Get-YarboConnectedWifi
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Start Wi-Fi hotspot (start_hotspot)')) {
            Write-Verbose (Protect-YarboLogMessage "[Start-YarboHotspot] Routing via local MQTT → start_hotspot")
            return Send-MqttCommand -Connection $conn -Command 'start_hotspot' -Payload @{}
        }
    }
}
