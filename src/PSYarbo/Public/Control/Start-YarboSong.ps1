function Start-YarboSong {
    <#
.SYNOPSIS
    Plays a song on the robot's speaker.

.DESCRIPTION
    Sends song_cmd with the specified song ID to play a built-in audio clip
    on the robot's speaker.

.PARAMETER SongId
    The ID of the song to play. Use 0 to stop playback.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Start-YarboSong -SongId 1

.EXAMPLE
    Start-YarboSong -SongId 0

.LINK
    Set-YarboSound
    Start-YarboBuzzer
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(0, 255)]
        [int]$SongId
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Play song songId=$SongId")) {
            Write-Verbose (Protect-YarboLogMessage "[Start-YarboSong] Routing via local MQTT → song_cmd (songId=$SongId)")
            return Send-MqttCommand -Connection $conn -Command 'song_cmd' -Payload @{ songId = $SongId }
        }
    }
}
