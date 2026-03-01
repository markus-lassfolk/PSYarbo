function Start-YarboWaypoint {
    <#
.SYNOPSIS
    Starts navigation to a saved waypoint.

.DESCRIPTION
    Sends start_way_point with the specified waypoint index to navigate the
    robot to a saved location.

.PARAMETER Index
    The zero-based index of the waypoint to navigate to.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Start-YarboWaypoint -Index 0

.EXAMPLE
    Start-YarboWaypoint -Index 2

.LINK
    Get-YarboRechargePoint
    Start-YarboRecharge
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(0, 255)]
        [int]$Index
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Start waypoint index=$Index")) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Start-YarboWaypoint] Routing via local MQTT → start_way_point (index=$Index)")
            return Send-MqttCommand -Connection $conn -Command 'start_way_point' -Payload @{ index = $Index }
        }
    }
}
