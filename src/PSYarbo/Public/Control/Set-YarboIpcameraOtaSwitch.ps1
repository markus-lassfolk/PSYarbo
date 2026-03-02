function Set-YarboIpcameraOtaSwitch {
    <#
.SYNOPSIS
    Sets IP camera OTA switch (set_ipcamera_ota_switch).
.EXAMPLE
    Set-YarboIpcameraOtaSwitch -State 1
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set IP camera OTA switch $State")) {
            Assert-YarboController -Connection $conn
            $cmd = 'set_ipcamera_ota_switch'
            return Send-MqttCommand -Connection $conn -Command $cmd -Payload @{ state = $State }
        }
    }
}
