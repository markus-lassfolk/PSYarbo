function Get-YarboRechargePoint {
    <#
.SYNOPSIS
    Retrieves the robot's saved recharge/docking point.

.DESCRIPTION
    Sends read_recharge_point and returns the data feedback response
    containing the coordinates or configuration of the charging station.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboRechargePoint

.EXAMPLE
    Get-YarboRechargePoint | ConvertTo-Json

.LINK
    Save-YarboChargingPoint
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
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboRechargePoint] Routing via local MQTT → read_recharge_point")
        $result = Send-MqttCommand -Connection $conn -Command 'read_recharge_point' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "read_recharge_point failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.ReadRechargePoint' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
