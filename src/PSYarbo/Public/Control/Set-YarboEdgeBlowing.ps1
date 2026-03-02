function Set-YarboEdgeBlowing {
    <#
.SYNOPSIS
    Sets edge blowing state (edge_blowing).
.EXAMPLE
    Set-YarboEdgeBlowing -State 1
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set edge blowing $State")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'edge_blowing' -Payload @{ state = $State }
        }
    }
}
