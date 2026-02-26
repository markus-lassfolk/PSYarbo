function Start-YarboBuzzer {
<#
.SYNOPSIS
    Activates the robot's buzzer.

.DESCRIPTION
    Sends cmd_buzzer with state=1 to turn on the robot's buzzer.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Start-YarboBuzzer

.LINK
    Stop-YarboBuzzer
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Start buzzer')) {
            Assert-YarboController -Connection $conn
            $payload = @{ state = 1; timeStamp = [long]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) }
            Send-MqttFireAndForget -Connection $conn -Command 'cmd_buzzer' -Payload $payload
        }
    }
}
