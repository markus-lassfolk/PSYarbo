function Set-YarboVelocity {
    <#
.SYNOPSIS
    Sets the robot's movement velocity during manual drive.

.DESCRIPTION
    Sends cmd_vel with linear and angular velocity. Requires manual drive mode.

.PARAMETER LinearVelocity
    Forward/reverse velocity in m/s. Range: -0.7 to 0.7.

.PARAMETER AngularVelocity
    Rotation velocity in rad/s. Range: -1.5 to 1.5. Default: 0.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboVelocity -LinearVelocity 0.3

.EXAMPLE
    Set-YarboVelocity -LinearVelocity 0.5 -AngularVelocity 0.3

.LINK
    Start-YarboManualDrive
    Stop-YarboManualDrive
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(-0.7, 0.7)]
        [double]$LinearVelocity,

        [Parameter(Position = 1)]
        [ValidateRange(-1.5, 1.5)]
        [double]$AngularVelocity = 0
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set velocity vel=$LinearVelocity rev=$AngularVelocity")) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboVelocity] Routing via local MQTT → cmd_vel")
            Send-MqttFireAndForget -Connection $conn -Command 'cmd_vel' -Payload @{ vel = $LinearVelocity; rev = $AngularVelocity }
        }
    }
}
