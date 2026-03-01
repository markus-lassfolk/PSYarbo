function Remove-YarboAllPlans {
    <#
.SYNOPSIS
    Deletes all work plans from the robot.

.DESCRIPTION
    Sends del_all_plan to remove every stored work plan from the robot.
    This action is irreversible — all plans will be permanently deleted.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Remove-YarboAllPlans

.EXAMPLE
    Remove-YarboAllPlans -Confirm:$false

.LINK
    Remove-YarboPlan
    Get-YarboPlan
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = '"AllPlans" explicitly conveys deleting every plan; the plural is intentional')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Delete all plans (del_all_plan)')) {
            Write-Verbose (Protect-YarboLogMessage "[Remove-YarboAllPlans] Routing via local MQTT → del_all_plan")
            Send-MqttCommand -Connection $conn -Command 'del_all_plan' -Payload @{} | Out-Null
        }
    }
}
