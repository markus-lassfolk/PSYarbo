function Stop-YarboBuzzer {
    <#
    .SYNOPSIS
        Deactivates the robot's buzzer.

    .DESCRIPTION
        Sends cmd_buzzer with state=0 to turn off the robot's buzzer.

    .PARAMETER Connection
        The connection to use. Defaults to the current default.

    .EXAMPLE
        Stop-YarboBuzzer

    .LINK
        Start-YarboBuzzer
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Stop buzzer')) {
            Assert-YarboController -Connection $conn
            $payload = @{ state = 0; timeStamp = [long]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) }
            Send-MqttFireAndForget -Connection $conn -Command 'cmd_buzzer' -Payload $payload
        }
    }
}
