function Invoke-YarboPlanAction {
    <#
.SYNOPSIS
    Sends an in-plan action command to the robot.

.DESCRIPTION
    Sends in_plan_action with the specified action string. This allows
    sending arbitrary plan control actions such as "pause", "resume",
    or attachment-specific commands while a plan is executing.

.PARAMETER Action
    The action string to send (e.g., "pause", "resume").

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Invoke-YarboPlanAction -Action "pause"

.EXAMPLE
    Invoke-YarboPlanAction -Action "resume"

.LINK
    Start-YarboPlan
    Suspend-YarboPlan
    Resume-YarboPlan
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Action
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "In-plan action '$Action'")) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Invoke-YarboPlanAction] Routing via local MQTT → in_plan_action (action=$Action)")
            return Send-MqttCommand -Connection $conn -Command 'in_plan_action' -Payload @{ action = $Action }
        }
    }
}
