function Restore-YarboMap {
    <#
.SYNOPSIS
    Restores a map from backup by ID (destructive).

.DESCRIPTION
    Sends map_recovery. Aligns with python-yarbo map_recovery. Requires -Confirm.

.PARAMETER MapId
    ID of the map backup to restore (from Get-YarboMapBackup).

.EXAMPLE
    Restore-YarboMap -MapId 'abc123' -Confirm
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$MapId,
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )
    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Restore map $MapId (destructive)")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'map_recovery' -Payload @{ mapId = $MapId }
        }
    }
}
