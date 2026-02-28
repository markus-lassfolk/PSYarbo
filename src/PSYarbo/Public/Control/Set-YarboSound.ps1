function Set-YarboSound {
    <#
.SYNOPSIS
    Sets the robot's speaker volume.

.DESCRIPTION
    Sends set_sound_param with the specified volume level. Volume typically
    ranges from 0 (mute) to 10 (maximum), though the exact range depends
    on the robot's firmware.

.PARAMETER Volume
    The volume level to set (0-10).

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboSound -Volume 5

.EXAMPLE
    Set-YarboSound -Volume 0

.LINK
    Start-YarboSong
    Start-YarboBuzzer
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(0, 10)]
        [int]$Volume
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set sound volume=$Volume")) {
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboSound] Routing via local MQTT → set_sound_param (vol=$Volume)")
            return Send-MqttCommand -Connection $conn -Command 'set_sound_param' -Payload @{ vol = $Volume }
        }
    }
}
