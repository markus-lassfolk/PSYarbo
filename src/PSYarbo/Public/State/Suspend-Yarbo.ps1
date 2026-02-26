function Suspend-Yarbo {
    <#
.SYNOPSIS
    Puts the robot to sleep.

.DESCRIPTION
    Sends set_working_state with state=0 to put the robot into sleep mode.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Suspend-Yarbo

.LINK
    Resume-Yarbo
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Sleep robot (set_working_state=0)')) {
            Write-Verbose (Protect-YarboLogMessage "[Suspend-Yarbo] Routing via local MQTT → set_working_state (state=0)")
            return Send-MqttCommand -Connection $conn -Command 'set_working_state' -Payload @{ state = 0 }
        }
    }
}
