function Set-YarboGreengrassUpdateSwitch {
    <#
.SYNOPSIS
    Sets Greengrass auto-update switch (set_greengrass_auto_update_switch).
.EXAMPLE
    Set-YarboGreengrassUpdateSwitch -State 1
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set Greengrass update switch $State")) {
            Assert-YarboController -Connection $conn
            $cmd = 'set_greengrass_auto_update_switch'
            return Send-MqttCommand -Connection $conn -Command $cmd -Payload @{ state = $State }
        }
    }
}
