function Get-YarboHeadCurrent {
    <#
.SYNOPSIS
    Retrieves head current measurements from the robot.

.DESCRIPTION
    Sends head_current_msg and returns the data feedback response containing
    current draw measurements for the robot's head/attachment electronics.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboHeadCurrent

.EXAMPLE
    Get-YarboHeadCurrent | ConvertTo-Json

.LINK
    Get-YarboBodyCurrent
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
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboHeadCurrent] Routing via local MQTT → head_current_msg")
        $result = Send-MqttCommand -Connection $conn -Command 'head_current_msg' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "head_current_msg failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.HeadCurrentMsg' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
