function Get-YarboBatteryCellTemps {
    <#
.SYNOPSIS
    Retrieves battery cell temperature readings from the robot.

.DESCRIPTION
    Sends battery_cell_temp_msg and returns the data feedback response
    containing individual battery cell temperature measurements.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboBatteryCellTemps

.EXAMPLE
    Get-YarboBatteryCellTemps | ConvertTo-Json

.LINK
    Get-YarboBattery
    Get-YarboMotorTemps
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = '"CellTemps" describes a collection of battery cell temperatures; the plural is intentional')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboBatteryCellTemps] Routing via local MQTT → battery_cell_temp_msg")
        $result = Send-MqttCommand -Connection $conn -Command 'battery_cell_temp_msg' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "battery_cell_temp_msg failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.BatteryCellTempMsg' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
