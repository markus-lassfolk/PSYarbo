function Get-YarboBodyCurrent {
    <#
.SYNOPSIS
    Retrieves body current measurements from the robot.

.DESCRIPTION
    Sends body_current_msg and returns the data feedback response containing
    current draw measurements for the robot's body electronics.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboBodyCurrent

.EXAMPLE
    Get-YarboBodyCurrent | ConvertTo-Json

.LINK
    Get-YarboHeadCurrent
    Get-YarboMotorTemps
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboBodyCurrent] Routing via local MQTT → body_current_msg")
        $result = Send-MqttCommand -Connection $conn -Command 'body_current_msg' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "body_current_msg failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.BodyCurrentMsg' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
