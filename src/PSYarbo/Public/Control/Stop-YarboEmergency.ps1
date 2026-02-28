function Stop-YarboEmergency {
    <#
.SYNOPSIS
    Triggers an emergency stop on the robot.

.DESCRIPTION
    Sends emergency_stop_active with state=true to immediately halt all robot
    motion. This is a hard stop for safety situations. Use Unlock-YarboEmergency
    to clear the emergency state afterwards.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Stop-YarboEmergency

.EXAMPLE
    Stop-YarboEmergency -Confirm:$false

.LINK
    Unlock-YarboEmergency
    Stop-Yarbo
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Emergency stop (emergency_stop_active)')) {
            Write-Verbose (Protect-YarboLogMessage "[Stop-YarboEmergency] Routing via local MQTT → emergency_stop_active")
            return Send-MqttCommand -Connection $conn -Command 'emergency_stop_active' -Payload @{ state = $true }
        }
    }
}
