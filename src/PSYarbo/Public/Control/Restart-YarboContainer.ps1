function Restart-YarboContainer {
    <#
.SYNOPSIS
    Restarts the robot's software container.

.DESCRIPTION
    Sends restart_container to restart the robot's on-board software stack
    without a full power cycle. Use this to recover from software issues.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Restart-YarboContainer

.LINK
    Stop-YarboShutdown
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Restart container (restart_container)')) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Restart-YarboContainer] Routing via local MQTT → restart_container")
            return Send-MqttCommand -Connection $conn -Command 'restart_container' -Payload @{}
        }
    }
}
