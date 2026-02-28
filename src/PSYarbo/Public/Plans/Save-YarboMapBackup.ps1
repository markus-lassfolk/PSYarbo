function Save-YarboMapBackup {
    <#
.SYNOPSIS
    Saves the current map as a backup on the robot.

.DESCRIPTION
    Sends save_map_backup to store the current navigation map as a named
    backup that can be retrieved later with Get-YarboMapBackup.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Save-YarboMapBackup

.LINK
    Get-YarboMapBackup
    Get-YarboMap
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Save map backup (save_map_backup)')) {
            Write-Verbose (Protect-YarboLogMessage "[Save-YarboMapBackup] Routing via local MQTT → save_map_backup")
            return Send-MqttCommand -Connection $conn -Command 'save_map_backup' -Payload @{}
        }
    }
}
