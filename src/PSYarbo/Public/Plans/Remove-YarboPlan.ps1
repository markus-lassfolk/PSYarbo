function Remove-YarboPlan {
<#
.SYNOPSIS
    Deletes a work plan from the robot.

.DESCRIPTION
    Sends del_plan to remove the specified plan.

.PARAMETER PlanId
    The plan ID to delete.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Remove-YarboPlan -PlanId 1

.EXAMPLE
    Get-YarboPlan -Name "Old Plan" | Remove-YarboPlan

.LINK
    Get-YarboPlan
    New-YarboPlan
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [int]$PlanId,

        [Parameter()]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Delete plan $PlanId")) {
            Write-Verbose (Protect-YarboLogMessage "[Remove-YarboPlan] Routing via local MQTT → del_plan")
            Send-MqttCommand -Connection $conn -Command 'del_plan' -Payload @{ planId = $PlanId } | Out-Null
        }
    }
}
