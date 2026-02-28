function Get-YarboWifiList {
    <#
.SYNOPSIS
    Retrieves the list of available Wi-Fi networks.

.DESCRIPTION
    Sends get_wifi_list and returns the data feedback response containing
    available Wi-Fi networks visible to the robot.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboWifiList

.EXAMPLE
    Get-YarboWifiList | ConvertTo-Json

.LINK
    Get-YarboConnectedWifi
    Start-YarboHotspot
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboWifiList] Routing via local MQTT → get_wifi_list")
        $result = Send-MqttCommand -Connection $conn -Command 'get_wifi_list' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "get_wifi_list failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.GetWifiList' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
