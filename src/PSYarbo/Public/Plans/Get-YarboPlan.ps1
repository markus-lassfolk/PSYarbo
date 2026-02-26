function Get-YarboPlan {
    <#
.SYNOPSIS
    Retrieves work plans from the robot.

.DESCRIPTION
    Queries the robot for stored work plans. Can return all plans,
    a specific plan by ID, or filter by name.

.PARAMETER PlanId
    Return a specific plan by ID.

.PARAMETER Name
    Filter plans by name (wildcard supported).

.PARAMETER All
    Return all plans (default).

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboPlan

.EXAMPLE
    Get-YarboPlan -PlanId 1

.EXAMPLE
    Get-YarboPlan -Name "Uteplats"

.LINK
    New-YarboPlan
    Remove-YarboPlan
    Start-YarboPlan
#>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([YarboPlan])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(ParameterSetName = 'ById', Position = 0)]
        [int]$PlanId,

        [Parameter(ParameterSetName = 'ByName')]
        [string]$Name,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection

        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            Write-Verbose (Protect-YarboLogMessage "[Get-YarboPlan] Routing via local MQTT → read_plan")
            $result = Send-MqttCommand -Connection $conn -Command 'read_plan' -Payload @{ planId = $PlanId }
            if ($result -and $result.Success -and $result.Data) {
                $plan = [YarboPlan]::new()
                $plan.Id = $result.Data.id
                $plan.Name = $result.Data.name
                $plan.AreaIds = @($result.Data.areaIds)
                $plan.EnableSelfOrder = [bool]$result.Data.enable_self_order
                return $plan
            }
            return $null
        }

        # Fetch all plans
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboPlan] Routing via local MQTT → read_all_plan")
        $result = Send-MqttCommand -Connection $conn -Command 'read_all_plan' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "read_all_plan failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.ReadAllPlan' -Category 'InvalidResult'))
            }
            return
        }

        $plans = @()
        foreach ($item in $result.Data) {
            $plan = [YarboPlan]::new()
            $plan.Id = $item.id
            $plan.Name = $item.name
            $plan.AreaIds = @($item.areaIds)
            $plan.EnableSelfOrder = [bool]$item.enable_self_order
            $plans += $plan
        }

        if ($Name) {
            $plans = $plans | Where-Object { $_.Name -like $Name }
        }

        return $plans
    }
}
