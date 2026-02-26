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
    [CmdletBinding(DefaultParameterSetName = 'ById', SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('Id')]
        [int]$PlanId,

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string]$Name
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection

        $resolvedId = if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $plan = Get-YarboPlan -Connection $conn -Name $Name
            if (-not $plan) {
                $PSCmdlet.WriteError((New-YarboError -Message "Plan '$Name' not found." -ErrorId 'PSYarbo.NotFound.Plan' -Category 'ObjectNotFound'))
                return
            }
            $plan.Id
        } else {
            $PlanId
        }

        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Start plan $resolvedId")) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Start-YarboPlan] Routing via local MQTT → start_plan (planId=$resolvedId)")
            $result = Send-MqttCommand -Connection $conn -Command 'start_plan' -Payload @{ planId = [int]$resolvedId }
            if ($result -and -not $result.Success) {
                $PSCmdlet.WriteError((New-YarboError -Message "start_plan failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.StartPlan' -Category 'InvalidResult' -TargetObject $result))
            }
            return $result
        }
    }
}
