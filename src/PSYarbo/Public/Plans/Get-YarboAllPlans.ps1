function Get-YarboAllPlans {
    <#
.SYNOPSIS
    Retrieves all work plans stored on the robot.

.DESCRIPTION
    Sends read_all_plan and returns the raw data feedback response containing
    all stored work plans. For typed plan objects with filtering, use Get-YarboPlan.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboAllPlans

.EXAMPLE
    Get-YarboAllPlans | ConvertTo-Json

.LINK
    Get-YarboPlan
    Remove-YarboAllPlans
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = '"AllPlans" explicitly conveys returning a collection of all plans; the plural is intentional')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboAllPlans] Routing via local MQTT → read_all_plan")
        $result = Send-MqttCommand -Connection $conn -Command 'read_all_plan' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "read_all_plan failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.ReadAllPlan' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
