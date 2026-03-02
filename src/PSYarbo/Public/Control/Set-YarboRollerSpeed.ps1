function Set-YarboRollerSpeed {
    <#
.SYNOPSIS
    Sets the roller/blower speed (leaf blower head).

.DESCRIPTION
    Sends set_roller_speed. Aligns with python-yarbo set_roller_speed.
    Distinct from Set-YarboRoller which uses cmd_roller (manual drive).

.PARAMETER Speed
    Speed value in robot-defined units.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboRollerSpeed -Speed 1000

.LINK
    Set-YarboRoller
    about_PSYarbo_Heads
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [int]$Speed,

        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set roller speed to $Speed")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'set_roller_speed' -Payload @{ speed = $Speed }
        }
    }
}
