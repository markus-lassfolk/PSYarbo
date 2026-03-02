function Set-YarboTurnType {
    <#
.SYNOPSIS
    Sets the turn type (set_turn_type).
.EXAMPLE
    Set-YarboTurnType -TurnType 1
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [int]$TurnType,
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )
    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set turn type to $TurnType")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'set_turn_type' -Payload @{ turnType = $TurnType }
        }
    }
}
