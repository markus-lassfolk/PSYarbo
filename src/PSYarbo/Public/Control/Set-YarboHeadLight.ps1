function Set-YarboHeadLight {
    <#
.SYNOPSIS
    Enables or disables the robot's head light.

.DESCRIPTION
    Sends head_light with state=1 (on) or state=0 (off) to control the
    robot's front headlight.

.PARAMETER Enabled
    $true to turn on, $false to turn off.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboHeadLight -Enabled $true

.EXAMPLE
    Set-YarboHeadLight -Enabled $false

.LINK
    Set-YarboLight
    Set-YarboRoofLights
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
        $state = if ($Enabled) { 1 } else { 0 }
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set head light state=$state")) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboHeadLight] Routing via local MQTT → head_light (state=$state)")
            return Send-MqttCommand -Connection $conn -Command 'head_light' -Payload @{ state = $state }
        }
    }
}
