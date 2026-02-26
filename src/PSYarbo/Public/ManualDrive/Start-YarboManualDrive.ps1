function Start-YarboManualDrive {
<#
.SYNOPSIS
    Enters manual drive mode on the robot.

.DESCRIPTION
    Wakes the robot (set_working_state=1) and enters manual control mode.
    After this, use Set-YarboVelocity, Set-YarboRoller, and Set-YarboChute.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Start-YarboManualDrive

.LINK
    Stop-YarboManualDrive
    Set-YarboVelocity
    Set-YarboRoller
    Set-YarboChute
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Enter manual drive mode')) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Start-YarboManualDrive] Routing via local MQTT → set_working_state + manual")
            Send-MqttCommand -Connection $conn -Command 'set_working_state' -Payload @{ state = 1 } | Out-Null
            return Send-MqttCommand -Connection $conn -Command 'manual' -Payload @{}
        }
    }
}
