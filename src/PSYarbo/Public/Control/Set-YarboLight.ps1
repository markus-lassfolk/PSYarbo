function Set-YarboLight {
    <#
.SYNOPSIS
    Controls the LED lights on a Yarbo robot.

.DESCRIPTION
    Sets the brightness of the robot's 7 LED channels: head light, left/right
    white fill lights, left/right body red lights, and left/right tail red lights.
    Values range from 0 (off) to 255 (full brightness).

    This command is fire-and-forget — no confirmation response is expected.

.PARAMETER Preset
    A named light configuration: AllOn, AllOff, HeadOnly, BodyOnly, TailOnly.

.PARAMETER HeadLight
    Front headlight brightness (0-255). Maps to 'led_head'.

.PARAMETER LeftWhite
    Left white fill light (0-255). Maps to 'led_left_w'.

.PARAMETER RightWhite
    Right white fill light (0-255). Maps to 'led_right_w'.

.PARAMETER BodyLeftRed
    Left body red light (0-255). Maps to 'body_left_r'.

.PARAMETER BodyRightRed
    Right body red light (0-255). Maps to 'body_right_r'.

.PARAMETER TailLeftRed
    Left tail red light (0-255). Maps to 'tail_left_r'.

.PARAMETER TailRightRed
    Right tail red light (0-255). Maps to 'tail_right_r'.

.PARAMETER State
    A YarboLightState object with all channel values pre-configured.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboLight AllOn

.EXAMPLE
    Set-YarboLight -HeadLight 255 -BodyLeftRed 128 -BodyRightRed 128

.LINK
    Connect-Yarbo
    Get-YarboStatus
#>
    [CmdletBinding(DefaultParameterSetName = 'Preset', SupportsShouldProcess)]
    [OutputType([YarboLightState])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory, ParameterSetName = 'Preset', Position = 0)]
        [ValidateSet('AllOn', 'AllOff', 'HeadOnly', 'BodyOnly', 'TailOnly')]
        [string]$Preset,

        [Parameter(ParameterSetName = 'Custom')]
        [ValidateRange(0, 255)]
        [int]$HeadLight = 0,

        [Parameter(ParameterSetName = 'Custom')]
        [ValidateRange(0, 255)]
        [int]$LeftWhite = 0,

        [Parameter(ParameterSetName = 'Custom')]
        [ValidateRange(0, 255)]
        [int]$RightWhite = 0,

        [Parameter(ParameterSetName = 'Custom')]
        [ValidateRange(0, 255)]
        [int]$BodyLeftRed = 0,

        [Parameter(ParameterSetName = 'Custom')]
        [ValidateRange(0, 255)]
        [int]$BodyRightRed = 0,

        [Parameter(ParameterSetName = 'Custom')]
        [ValidateRange(0, 255)]
        [int]$TailLeftRed = 0,

        [Parameter(ParameterSetName = 'Custom')]
        [ValidateRange(0, 255)]
        [int]$TailRightRed = 0,

        [Parameter(Mandatory, ParameterSetName = 'Raw')]
        [YarboLightState]$State
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection

        $lightState = switch ($PSCmdlet.ParameterSetName) {
            'Preset' {
                switch ($Preset) {
                    'AllOn' { [YarboLightState]::AllOn() }
                    'AllOff' { [YarboLightState]::AllOff() }
                    'HeadOnly' {
                        $s = [YarboLightState]::new(); $s.HeadLight = 255; $s
                    }
                    'BodyOnly' {
                        $s = [YarboLightState]::new()
                        $s.LeftWhite = 255; $s.RightWhite = 255
                        $s.BodyLeftRed = 255; $s.BodyRightRed = 255; $s
                    }
                    'TailOnly' {
                        $s = [YarboLightState]::new()
                        $s.TailLeftRed = 255; $s.TailRightRed = 255; $s
                    }
                }
            }
            'Custom' {
                $s = [YarboLightState]::new()
                $s.HeadLight = $HeadLight; $s.LeftWhite = $LeftWhite; $s.RightWhite = $RightWhite
                $s.BodyLeftRed = $BodyLeftRed; $s.BodyRightRed = $BodyRightRed
                $s.TailLeftRed = $TailLeftRed; $s.TailRightRed = $TailRightRed; $s
            }
            'Raw' { $State }
        }

        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set lights: $lightState")) {
            Assert-YarboController -Connection $conn
            Send-MqttFireAndForget -Connection $conn -Command 'light_ctrl' -Payload $lightState.ToPayload()
            return $lightState
        }
    }
}
