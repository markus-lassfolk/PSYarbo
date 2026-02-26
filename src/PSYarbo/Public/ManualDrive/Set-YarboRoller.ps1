function Set-YarboRoller {
<#
.SYNOPSIS
    Sets the roller/auger speed during manual drive.

.DESCRIPTION
    Sends cmd_roller with the specified RPM. Requires manual drive mode.

.PARAMETER Speed
    Roller speed in RPM. Range: 0 to 2000.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboRoller -Speed 1000

.LINK
    Start-YarboManualDrive
    Set-YarboVelocity
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(0, 2000)]
        [int]$Speed
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set roller speed=$Speed RPM")) {
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboRoller] Routing via local MQTT → cmd_roller")
            Send-MqttFireAndForget -Connection $conn -Command 'cmd_roller' -Payload @{ vel = $Speed }
        }
    }
}
