function Set-YarboLaser {
    <#
.SYNOPSIS
    Enables or disables the robot's laser.

.DESCRIPTION
    Sends laser_toggle with enabled=true or enabled=false to control the
    robot's laser sensor/emitter.

.PARAMETER Enabled
    $true to enable, $false to disable.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboLaser -Enabled $true

.EXAMPLE
    Set-YarboLaser -Enabled $false

.LINK
    Set-YarboCamera
    Set-YarboPersonDetect
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory, Position = 0)]
        [bool]$Enabled
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set laser enabled=$Enabled")) {
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboLaser] Routing via local MQTT → laser_toggle (enabled=$Enabled)")
            return Send-MqttCommand -Connection $conn -Command 'laser_toggle' -Payload @{ enabled = $Enabled }
        }
    }
}
