function Save-YarboCurrentMap {
    <#
.SYNOPSIS
    Saves the robot's current map state.

.DESCRIPTION
    Sends save_current_map. Aligns with python-yarbo save_current_map.
    Distinct from Save-YarboMapBackup which triggers a full backup.

.EXAMPLE
    Save-YarboCurrentMap
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )
    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Save current map')) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'save_current_map' -Payload @{}
        }
    }
}
