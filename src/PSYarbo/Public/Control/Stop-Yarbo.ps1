function Stop-Yarbo {
    <#
.SYNOPSIS
    Performs a soft stop of the robot.

.DESCRIPTION
    Sends dstop to gracefully stop robot motion. Unlike Stop-YarboEmergency,
    this is a controlled deceleration stop that does not trigger emergency state.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Stop-Yarbo

.LINK
    Stop-YarboEmergency
    Resume-YarboPlan
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Soft stop (dstop)')) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Stop-Yarbo] Routing via local MQTT → dstop")
            return Send-MqttCommand -Connection $conn -Command 'dstop' -Payload @{}
        }
    }
}
