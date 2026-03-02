function Start-YarboDrawCmd {
    <#
.SYNOPSIS
    Starts draw command (start_draw_cmd).
.EXAMPLE
    Start-YarboDrawCmd -State 1
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Start draw cmd $State")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'start_draw_cmd' -Payload @{ state = $State }
        }
    }
}
