function Stop-YarboManualDrive {
    <#
.SYNOPSIS
    Exits manual drive mode and stops the robot.

.DESCRIPTION
    Sends one of three stop commands depending on the switch used:

    (default)  dstop               — graceful stop, exits manual drive cleanly
    -HardStop  dstopp              — immediate hard stop, abrupt deceleration
    -Emergency emergency_stop_active — emergency halt, highest priority stop

.PARAMETER HardStop
    Send dstopp (immediate hard stop) instead of the default graceful dstop.

.PARAMETER Emergency
    Use emergency stop (emergency_stop_active) instead of graceful stop.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Stop-YarboManualDrive

.EXAMPLE
    Stop-YarboManualDrive -HardStop

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
        [switch]$HardStop,

        [Parameter()]
        [switch]$Emergency
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection

        $cmd = if ($Emergency) {
            'emergency_stop_active'
        } elseif ($HardStop) {
            'dstopp'
        } else {
            'dstop'
        }

        $action = if ($Emergency) {
            'Emergency stop'
        } elseif ($HardStop) {
            'Hard stop manual drive (dstopp)'
        } else {
            'Stop manual drive'
        }

        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, $action)) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Stop-YarboManualDrive] Routing via local MQTT → $cmd")
            return Send-MqttCommand -Connection $conn -Command $cmd -Payload @{}
        }
    }
}
