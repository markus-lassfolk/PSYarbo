function Set-YarboRoofLights {
    <#
.SYNOPSIS
    Enables or disables the robot's roof lights.

.DESCRIPTION
    Sends roof_lights_enable with enable=1 (on) or enable=0 (off) to control
    the robot's roof light strip.

.PARAMETER Enabled
    $true to turn on, $false to turn off.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboRoofLights -Enabled $true

.EXAMPLE
    Set-YarboRoofLights -Enabled $false

.LINK
    Set-YarboHeadLight
    Set-YarboLight
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = '"RoofLights" refers to the physical light strip assembly; the plural matches the hardware name')]
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
        $enable = if ($Enabled) { 1 } else { 0 }
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set roof lights enable=$enable")) {
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboRoofLights] Routing via local MQTT → roof_lights_enable (enable=$enable)")
            return Send-MqttCommand -Connection $conn -Command 'roof_lights_enable' -Payload @{ enable = $enable }
        }
    }
}
