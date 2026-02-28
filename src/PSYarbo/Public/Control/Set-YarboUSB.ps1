function Set-YarboUSB {
    <#
.SYNOPSIS
    Enables or disables the robot's USB interface.

.DESCRIPTION
    Sends usb_toggle with enabled=true or enabled=false to control the
    robot's USB port power.

.PARAMETER Enabled
    $true to enable, $false to disable.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboUSB -Enabled $true

.EXAMPLE
    Set-YarboUSB -Enabled $false

.LINK
    Set-YarboCamera
    Get-YarboHubInfo
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
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set USB enabled=$Enabled")) {
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboUSB] Routing via local MQTT → usb_toggle (enabled=$Enabled)")
            return Send-MqttCommand -Connection $conn -Command 'usb_toggle' -Payload @{ enabled = $Enabled }
        }
    }
}
