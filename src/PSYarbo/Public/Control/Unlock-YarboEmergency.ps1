function Unlock-YarboEmergency {
    <#
.SYNOPSIS
    Clears the emergency stop state on the robot.

.DESCRIPTION
    Sends emergency_unlock to release the robot from emergency stop mode.
    Must be called after Stop-YarboEmergency before the robot can resume
    normal operation.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Unlock-YarboEmergency

.LINK
    Stop-YarboEmergency
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Unlock emergency stop (emergency_unlock)')) {
            Write-Verbose (Protect-YarboLogMessage "[Unlock-YarboEmergency] Routing via local MQTT → emergency_unlock")
            return Send-MqttCommand -Connection $conn -Command 'emergency_unlock' -Payload @{}
        }
    }
}
