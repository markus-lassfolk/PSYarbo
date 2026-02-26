function Set-YarboChute {
    <#
.SYNOPSIS
    Controls the snow chute direction/speed.

.DESCRIPTION
    Sends cmd_chute with the specified velocity to control the snow discharge chute.
    Requires manual drive mode.

.PARAMETER Velocity
    Chute velocity. Positive/negative controls direction.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboChute -Velocity 100

.EXAMPLE
    Set-YarboChute -Velocity -50

.LINK
    Start-YarboManualDrive
    Set-YarboRoller
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory, Position = 0)]
        [int]$Velocity
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set chute velocity=$Velocity")) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboChute] Routing via local MQTT → cmd_chute")
            Send-MqttFireAndForget -Connection $conn -Command 'cmd_chute' -Payload @{ vel = $Velocity }
        }
    }
}
