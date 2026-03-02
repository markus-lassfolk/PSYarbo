function Set-YarboBladeHeight {
    <#
.SYNOPSIS
    Sets the blade cutting height (lawn mower heads).

.DESCRIPTION
    Sends set_blade_height. Aligns with python-yarbo set_blade_height.
    Lawn Mower / Lawn Mower Pro heads.

.PARAMETER Height
    Blade height value in robot-defined units.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboBladeHeight -Height 3

.LINK
    Set-YarboBladeSpeed
    about_PSYarbo_Heads
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [int]$Height,

        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set blade height to $Height")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'set_blade_height' -Payload @{ height = $Height }
        }
    }
}
