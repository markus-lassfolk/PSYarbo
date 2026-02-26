function Suspend-YarboPlan {
<#
.SYNOPSIS
    Pauses the currently running plan.

.DESCRIPTION
    Sends the planning_paused command to pause plan execution.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Suspend-YarboPlan

.LINK
    Resume-YarboPlan
    Stop-YarboPlan
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Suspend plan')) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'planning_paused' -Payload @{}
        }
    }
}
