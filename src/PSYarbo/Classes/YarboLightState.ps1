class YarboLightState {
    [ValidateRange(0,255)] [int]$HeadLight        # led_head
    [ValidateRange(0,255)] [int]$LeftWhite         # led_left_w
    [ValidateRange(0,255)] [int]$RightWhite        # led_right_w
    [ValidateRange(0,255)] [int]$BodyLeftRed       # body_left_r
    [ValidateRange(0,255)] [int]$BodyRightRed      # body_right_r
    [ValidateRange(0,255)] [int]$TailLeftRed       # tail_left_r
    [ValidateRange(0,255)] [int]$TailRightRed      # tail_right_r

    [hashtable] ToPayload() {
        return @{
            led_head     = $this.HeadLight
            led_left_w   = $this.LeftWhite
            led_right_w  = $this.RightWhite
            body_left_r  = $this.BodyLeftRed
            body_right_r = $this.BodyRightRed
            tail_left_r  = $this.TailLeftRed
            tail_right_r = $this.TailRightRed
        }
    }

    static [YarboLightState] AllOn() {
        $s = [YarboLightState]::new()
        $s.HeadLight = 255; $s.LeftWhite = 255; $s.RightWhite = 255
        $s.BodyLeftRed = 255; $s.BodyRightRed = 255
        $s.TailLeftRed = 255; $s.TailRightRed = 255
        return $s
    }

    static [YarboLightState] AllOff() {
        return [YarboLightState]::new()
    }

    [string] ToString() {
        return "Head:$($this.HeadLight) L:$($this.LeftWhite) R:$($this.RightWhite) BL:$($this.BodyLeftRed) BR:$($this.BodyRightRed) TL:$($this.TailLeftRed) TR:$($this.TailRightRed)"
    }
}
