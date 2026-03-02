function Clear-YarboMap {
    <#
.SYNOPSIS
    Erases the robot's stored map (destructive).

.DESCRIPTION
    Sends erase_map. Aligns with python-yarbo erase_map. Requires -Confirm.

.EXAMPLE
    Clear-YarboMap -Confirm
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )
    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Erase map (destructive)')) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'erase_map' -Payload @{}
        }
    }
}
