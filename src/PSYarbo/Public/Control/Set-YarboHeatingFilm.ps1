function Set-YarboHeatingFilm {
    <#
.SYNOPSIS
    Controls heating film (heating_film_ctrl).
.EXAMPLE
    Set-YarboHeatingFilm -State 1
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set heating film $State")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'heating_film_ctrl' -Payload @{ state = $State }
        }
    }
}
