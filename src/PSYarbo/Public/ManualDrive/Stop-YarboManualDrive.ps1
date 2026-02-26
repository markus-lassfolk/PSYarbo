function Stop-YarboManualDrive {
    <#
.SYNOPSIS
    Exits manual drive mode and stops the robot.

.DESCRIPTION
    Sends dstop to gracefully stop, or emergency_stop_active for an emergency halt.

.PARAMETER Emergency
    Use emergency stop instead of graceful stop.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Stop-YarboManualDrive

.EXAMPLE
    Stop-YarboManualDrive -Emergency

.LINK
    Start-YarboManualDrive
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter()]
        [switch]$Emergency
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        $cmd = if ($Emergency) { 'emergency_stop_active' } else { 'dstop' }
        $action = if ($Emergency) { 'Emergency stop' } else { 'Stop manual drive' }

        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, $action)) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Stop-YarboManualDrive] Routing via local MQTT → $cmd")
            return Send-MqttCommand -Connection $conn -Command $cmd -Payload @{}
        }
    }
}
