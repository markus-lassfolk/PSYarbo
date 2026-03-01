function Save-YarboChargingPoint {
    <#
.SYNOPSIS
    Saves the robot's current position as the charging/docking point.

.DESCRIPTION
    Sends save_charging_point to store the robot's current GPS position
    as the reference charging station location.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Save-YarboChargingPoint

.LINK
    Get-YarboRechargePoint
    Start-YarboRecharge
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Save current position as charging point')) {
            Write-Verbose (Protect-YarboLogMessage "[Save-YarboChargingPoint] Routing via local MQTT → save_charging_point")
            return Send-MqttCommand -Connection $conn -Command 'save_charging_point' -Payload @{}
        }
    }
}
