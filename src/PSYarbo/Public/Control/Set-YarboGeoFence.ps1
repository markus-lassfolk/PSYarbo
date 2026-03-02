function Set-YarboGeoFence {
    <#
.SYNOPSIS
    Enables or disables geo fence (enable_geo_fence).
.EXAMPLE
    Set-YarboGeoFence -State 1
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set GeoFence $State")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'enable_geo_fence' -Payload @{ state = $State }
        }
    }
}
