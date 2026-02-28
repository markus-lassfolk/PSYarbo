function Stop-YarboShutdown {
    <#
.SYNOPSIS
    Powers off the robot completely.

.DESCRIPTION
    Sends the shutdown command to power off the robot. This requires a physical
    restart — the robot cannot be brought back online remotely after this command.
    Verified live: "shutdown" is the correct command name.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Stop-YarboShutdown

.EXAMPLE
    Stop-YarboShutdown -Confirm:$false

.LINK
    Restart-YarboContainer
    Connect-Yarbo
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Shutdown robot (shutdown) — requires physical restart')) {
            Write-Verbose (Protect-YarboLogMessage "[Stop-YarboShutdown] Routing via local MQTT → shutdown")
            return Send-MqttCommand -Connection $conn -Command 'shutdown' -Payload @{}
        }
    }
}
