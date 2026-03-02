function Set-YarboSmartBlowing {
    <#
.SYNOPSIS
    Sets smart blowing state (smart_blowing).
.EXAMPLE
    Set-YarboSmartBlowing -State 1
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set smart blowing $State")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'smart_blowing' -Payload @{ state = $State }
        }
    }
}
