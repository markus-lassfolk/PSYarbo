function Get-YarboSavedWifiList {
    <#
.SYNOPSIS
    Retrieves the list of saved Wi-Fi networks on the robot.

.DESCRIPTION
    Sends get_saved_wifi_list and returns the data feedback response containing
    Wi-Fi networks previously saved on the robot. Aligns with python-yarbo
    get_saved_wifi_list.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboSavedWifiList

.EXAMPLE
    Get-YarboSavedWifiList | ConvertTo-Json

.LINK
    Get-YarboWifiList
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
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboSavedWifiList] Routing via local MQTT → get_saved_wifi_list")
        $result = Send-MqttCommand -Connection $conn -Command 'get_saved_wifi_list' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "get_saved_wifi_list failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.GetSavedWifiList' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
