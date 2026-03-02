function Set-YarboSmartVision {
    <#
.SYNOPSIS
    Sets smart vision state (smart_vision_control).
.EXAMPLE
    Set-YarboSmartVision -State 1
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set smart vision $State")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'smart_vision_control' -Payload @{ state = $State }
        }
    }
}
