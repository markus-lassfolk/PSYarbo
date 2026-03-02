function Set-YarboElecFence {
    <#
.SYNOPSIS
    Enables or disables electric fence (enable_elec_fence).
.EXAMPLE
    Set-YarboElecFence -State 1
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set ElecFence $State")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'enable_elec_fence' -Payload @{ state = $State }
        }
    }
}
