function Set-YarboTrimmer {
    <#
.SYNOPSIS
    Sets trimmer state (cmd_trimmer).
.EXAMPLE
    Set-YarboTrimmer -State 1
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set trimmer $State")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'cmd_trimmer' -Payload @{ state = $State }
        }
    }
}
