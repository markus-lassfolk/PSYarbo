function Send-YarboCommand {
<#
.SYNOPSIS
    Sends a raw MQTT command to the robot.

.DESCRIPTION
    Pass-through for advanced users. Sends any command with any payload
    to the robot's MQTT command topic. Use for commands not yet wrapped
    in dedicated cmdlets.

.PARAMETER Command
    The MQTT command name (e.g., 'get_controller', 'erase_map').

.PARAMETER Payload
    A hashtable payload to send. Default: empty.

.PARAMETER TimeoutSeconds
    Response timeout in seconds. Default: 5.

.PARAMETER NoWait
    Fire-and-forget — don't wait for a response.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Send-YarboCommand -Command 'read_global_params'

.EXAMPLE
    Send-YarboCommand -Command 'light_ctrl' -Payload @{led_head=255} -NoWait

.LINK
    Connect-Yarbo
    Get-YarboLog
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory, Position = 0)]
        [string]$Command,

        [Parameter(Position = 1)]
        [hashtable]$Payload = @{},

        [Parameter()]
        [int]$TimeoutSeconds = 5,

        [Parameter()]
        [switch]$NoWait
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Send command '$Command'")) {
            if ($NoWait) {
                Send-MqttFireAndForget -Connection $conn -Command $Command -Payload $Payload
                return $null
            }
            return Send-MqttCommand -Connection $conn -Command $Command -Payload $Payload -TimeoutMs ($TimeoutSeconds * 1000)
        }
    }
}
