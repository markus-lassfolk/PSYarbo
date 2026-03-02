function Set-YarboNgzEdge {
    <#
.SYNOPSIS
    Sets NGZ edge state (ngz_edge).
.EXAMPLE
    Set-YarboNgzEdge -State 1
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet(0, 1)]
        [int]$State,
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )
    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set NgzEdge $State")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'ngz_edge' -Payload @{ state = $State }
        }
    }
}
