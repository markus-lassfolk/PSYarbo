function Get-YarboNoChargePeriod {
    <#
.SYNOPSIS
    Retrieves the no-charge period configuration from the robot.

.DESCRIPTION
    Sends read_no_charge_period and returns the data feedback response
    containing the configured time periods during which the robot will
    not attempt to charge.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboNoChargePeriod

.EXAMPLE
    Get-YarboNoChargePeriod | ConvertTo-Json

.LINK
    Get-YarboSchedule
    Start-YarboRecharge
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboNoChargePeriod] Routing via local MQTT → read_no_charge_period")
        $result = Send-MqttCommand -Connection $conn -Command 'read_no_charge_period' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "read_no_charge_period failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.ReadNoChargePeriod' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
