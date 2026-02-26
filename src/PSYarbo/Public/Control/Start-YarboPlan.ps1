function Start-YarboPlan {
<#
.SYNOPSIS
    Starts execution of a Yarbo work plan.

.DESCRIPTION
    Sends the start_plan command with the specified plan ID.

.PARAMETER PlanId
    The numeric plan ID to start.

.PARAMETER Name
    Plan name — resolved to PlanId via Get-YarboPlan.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Start-YarboPlan -PlanId 1

.EXAMPLE
    Get-YarboPlan -Name "Uteplats" | Start-YarboPlan

.LINK
    Stop-YarboPlan
    Get-YarboPlan
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [int]$PlanId,

        [Parameter()]
        [string]$Name
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection

        if ($Name) {
            $plan = Get-YarboPlan -Connection $conn -Name $Name
            if (-not $plan) {
                $PSCmdlet.WriteError((New-YarboError -Message "Plan '$Name' not found." -ErrorId 'PSYarbo.NotFound.Plan' -Category 'ObjectNotFound'))
                return
            }
            $PlanId = $plan.Id
        }

        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Start plan $PlanId")) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Start-YarboPlan] Routing via local MQTT → start_plan (planId=$PlanId)")
            $result = Send-MqttCommand -Connection $conn -Command 'start_plan' -Payload @{ planId = $PlanId }
            if ($result -and -not $result.Success) {
                $PSCmdlet.WriteError((New-YarboError -Message "start_plan failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.StartPlan' -Category 'InvalidResult' -TargetObject $result))
            }
            return $result
        }
    }
}
