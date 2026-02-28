function Get-YarboHubInfo {
    <#
.SYNOPSIS
    Retrieves hub/connectivity information from the robot.

.DESCRIPTION
    Sends hub_info and returns the data feedback response containing
    information about the robot's network hub and connectivity state.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboHubInfo

.EXAMPLE
    Get-YarboHubInfo | ConvertTo-Json

.LINK
    Get-YarboConnectedWifi
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
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboHubInfo] Routing via local MQTT → hub_info")
        $result = Send-MqttCommand -Connection $conn -Command 'hub_info' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "hub_info failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.HubInfo' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
