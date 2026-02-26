function New-YarboPlan {
    <#
.SYNOPSIS
    Creates a new work plan on the robot.

.DESCRIPTION
    Sends the save_plan command to create a new plan with the given name and areas.

.PARAMETER Name
    The plan name.

.PARAMETER AreaIds
    Array of area IDs to include in the plan.

.PARAMETER EnableSelfOrder
    Enable self-ordering of areas.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    New-YarboPlan -Name "Front Yard" -AreaIds 1,2,3

.OUTPUTS
    YarboPlan on success; YarboCommandResult on MQTT failure (caller can check .Success).

.LINK
    Get-YarboPlan
    Remove-YarboPlan
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([YarboPlan], [YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [int[]]$AreaIds,

        [Parameter()]
        [switch]$EnableSelfOrder
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Create plan '$Name'")) {
            $payload = @{
                name              = $Name
                areaIds           = $AreaIds
                enable_self_order = [bool]$EnableSelfOrder
            }
            Write-Verbose (Protect-YarboLogMessage "[New-YarboPlan] Routing via local MQTT → save_plan")
            $result = Send-MqttCommand -Connection $conn -Command 'save_plan' -Payload $payload
            if ($result -and $result.Success) {
                return Get-YarboPlan -Connection $conn -Name $Name
            }
            return $result
        }
    }
}
