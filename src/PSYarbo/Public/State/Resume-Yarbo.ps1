function Resume-Yarbo {
    <#
.SYNOPSIS
    Wakes the robot from sleep.

.DESCRIPTION
    Sends set_working_state with state=1 to wake the robot without entering
    manual drive mode. Use Start-YarboManualDrive if you need manual control.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Resume-Yarbo

.LINK
    Suspend-Yarbo
    Start-YarboManualDrive
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Wake robot (set_working_state=1)')) {
            Write-Verbose (Protect-YarboLogMessage "[Resume-Yarbo] Routing via local MQTT → set_working_state (state=1)")
            return Send-MqttCommand -Connection $conn -Command 'set_working_state' -Payload @{ state = 1 }
        }
    }
}
