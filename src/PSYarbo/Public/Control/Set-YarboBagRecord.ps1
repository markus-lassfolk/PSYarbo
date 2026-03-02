function Set-YarboBagRecord {
    <#
.SYNOPSIS
    Enables or disables bag record (bag_record).
.EXAMPLE
    Set-YarboBagRecord -Enabled $true
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [bool]$Enabled,
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )
    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        $state = if ($Enabled) { 1 } else { 0 }
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set bag record $state")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'bag_record' -Payload @{ state = $state }
        }
    }
}
