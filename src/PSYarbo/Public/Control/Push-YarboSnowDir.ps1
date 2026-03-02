function Push-YarboSnowDir {
    <#
.SYNOPSIS
    Pushes snow chute direction (push_snow_dir).
.EXAMPLE
    Push-YarboSnowDir -Direction 0
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [int]$Direction,
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )
    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Push snow dir $Direction")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'push_snow_dir' -Payload @{ dir = $Direction }
        }
    }
}
