function Set-YarboBladeSpeed {
    <#
.SYNOPSIS
    Sets the mower blade rotation speed.

.DESCRIPTION
    Sends set_blade_speed to set the blade speed (Lawn Mower / Lawn Mower Pro heads).
    Aligns with python-yarbo set_blade_speed. Speed units are robot-defined.

.PARAMETER Speed
    Blade speed value (robot-defined units; typically 0–max range).

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboBladeSpeed -Speed 1500

.LINK
    Set-YarboGlobalParams
    Get-YarboStatus
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set blade speed to $Speed")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'set_blade_speed' -Payload @{ speed = $Speed }
        }
    }
}
