function Set-YarboCamera {
    <#
.SYNOPSIS
    Enables or disables the robot's camera.

.DESCRIPTION
    Sends camera_toggle with enabled=true or enabled=false to control the
    robot's onboard camera.

.PARAMETER Enabled
    $true to enable, $false to disable.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboCamera -Enabled $true

.EXAMPLE
    Set-YarboCamera -Enabled $false

.LINK
    Set-YarboPersonDetect
    Set-YarboLaser
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set camera enabled=$Enabled")) {
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboCamera] Routing via local MQTT → camera_toggle (enabled=$Enabled)")
            return Send-MqttCommand -Connection $conn -Command 'camera_toggle' -Payload @{ enabled = $Enabled }
        }
    }
}
