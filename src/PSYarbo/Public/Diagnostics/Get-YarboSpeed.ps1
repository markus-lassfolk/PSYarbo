function Get-YarboSpeed {
    <#
.SYNOPSIS
    Retrieves current speed data from the robot.

.DESCRIPTION
    Sends speed_msg and returns the data feedback response containing the
    robot's current velocity and speed measurements.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboSpeed

.EXAMPLE
    Get-YarboSpeed | ConvertTo-Json

.LINK
    Get-YarboOdometer
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
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboSpeed] Routing via local MQTT → speed_msg")
        $result = Send-MqttCommand -Connection $conn -Command 'speed_msg' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "speed_msg failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.SpeedMsg' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
