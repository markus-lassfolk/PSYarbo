function Set-YarboMotorProtect {
    <#
.SYNOPSIS
    Sets motor protect state (cmd_motor_protect).
.EXAMPLE
    Set-YarboMotorProtect -State 1
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set motor protect $State")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'cmd_motor_protect' -Payload @{ state = $State }
        }
    }
}
