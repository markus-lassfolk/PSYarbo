function Stop-YarboPlan {
    <#
.SYNOPSIS
    Stops the currently running plan.

.DESCRIPTION
    Sends the stop_plan command to halt plan execution. Aligns with python-yarbo.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Stop-YarboPlan

.LINK
    Start-YarboPlan
    Suspend-YarboPlan
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Stop plan')) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'stop_plan' -Payload @{}
        }
    }
}
