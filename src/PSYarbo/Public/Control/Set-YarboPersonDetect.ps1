function Set-YarboPersonDetect {
    <#
.SYNOPSIS
    Enables or disables person detection on the robot.

.DESCRIPTION
    Sends set_person_detect with enable=1 or enable=0 to toggle the robot's
    person/obstacle detection feature. When enabled, the robot will stop
    or slow down when a person is detected.

.PARAMETER Enabled
    $true to enable detection, $false to disable.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboPersonDetect -Enabled $true

.EXAMPLE
    Set-YarboPersonDetect -Enabled $false

.LINK
    Set-YarboCamera
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
        $enable = if ($Enabled) { 1 } else { 0 }
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set person detect enable=$enable")) {
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboPersonDetect] Routing via local MQTT → set_person_detect (enable=$enable)")
            return Send-MqttCommand -Connection $conn -Command 'set_person_detect' -Payload @{ enable = $enable }
        }
    }
}
