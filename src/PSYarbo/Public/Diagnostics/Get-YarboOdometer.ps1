function Get-YarboOdometer {
    <#
.SYNOPSIS
    Retrieves odometer data from the robot.

.DESCRIPTION
    Sends odometer_msg and returns the data feedback response containing the
    robot's cumulative distance and runtime measurements.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboOdometer

.EXAMPLE
    Get-YarboOdometer | ConvertTo-Json

.LINK
    Get-YarboSpeed
    Get-YarboStatus
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboOdometer] Routing via local MQTT → odometer_msg")
        $result = Send-MqttCommand -Connection $conn -Command 'odometer_msg' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "odometer_msg failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.OdometerMsg' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
