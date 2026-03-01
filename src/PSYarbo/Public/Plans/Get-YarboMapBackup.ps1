function Get-YarboMapBackup {
    <#
.SYNOPSIS
    Retrieves all map backups from the robot.

.DESCRIPTION
    Sends get_all_map_backup and returns the data feedback response containing
    all saved map backup records.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboMapBackup

.EXAMPLE
    Get-YarboMapBackup | ConvertTo-Json -Depth 5

.LINK
    Save-YarboMapBackup
    Get-YarboMap
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboMapBackup] Routing via local MQTT → get_all_map_backup")
        $result = Send-MqttCommand -Connection $conn -Command 'get_all_map_backup' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "get_all_map_backup failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.GetAllMapBackup' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
