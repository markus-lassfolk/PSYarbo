function Get-YarboConnectedWifi {
    <#
.SYNOPSIS
    Retrieves the name of the currently connected Wi-Fi network.

.DESCRIPTION
    Sends get_connect_wifi_name and returns the data feedback response
    containing the SSID of the Wi-Fi network the robot is connected to.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboConnectedWifi

.LINK
    Get-YarboWifiList
    Get-YarboHubInfo
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboConnectedWifi] Routing via local MQTT → get_connect_wifi_name")
        $result = Send-MqttCommand -Connection $conn -Command 'get_connect_wifi_name' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "get_connect_wifi_name failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.GetConnectWifiName' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
