class YarboTelemetry {
    [datetime]$Timestamp
    [string]$SerialNumber

    # Battery (BatteryMSG)
    [int]$BatteryCapacity
    [int]$BatteryStatus
    [bool]$BatteryTempError
    [double]$BatteryTimestamp
    [double]$BatteryCurrent
    [double]$BatteryVoltage

    # Body (BodyMsg)
    [int]$RechargeState

    # Position (CombinedOdom, RTKMSG, combined_odom_confidence)
    [double]$X
    [double]$Y
    [double]$Phi
    [double]$Heading
    [int]$RtkHeadingStatus
    [string]$RtkStatus
    [double]$RtkHeadingDop
    [double]$OdomConfidence
    [double]$RtkGgaAtnDis
    [double]$RtkHeadingAtnDis
    [int]$RtkHeadingMulti
    [int]$RtkHeadingObs
    [double]$RtkPre4Timestamp
    [string]$RtkVersion
    [int]$RtkSatNum
    [double]$RtkTimestamp
    [double]$RtcmAge
    [object]$RtcmInfo
    [string]$RoverHeading
    [string]$BaseGngga

    # Running status (RunningStatusMSG)
    [int]$ChuteAngle
    [int]$ChuteSteeringEngineInfo
    [int]$ChuteSteeringRunStatus
    [double]$HeadGyroPitch
    [double]$HeadGyroRoll
    [int]$RainSensorData
    [int]$PushPodStatus
    [int]$PushRodPlace
    [int]$SnowPipeRunStatus
    [int]$SnowRollerMotor
    [int]$ElecNavigationFrontRightSensor
    [int]$ElecNavigationRearRightSensor

    # State (StateMSG)
    [int]$WorkingState
    [int]$ChargingStatus
    [int]$ErrorCode
    [bool]$IsPlanning
    [bool]$IsPaused
    [bool]$IsRecharging
    [int]$AdjustAngleStatus
    [int]$AutoDrawWaitingState
    [int]$EnStateLed
    [int]$EnWarnLed
    [bool]$OnGoingToStartPoint
    [bool]$OnMulPoints
    [int]$RobotFollowState
    [int]$ScheduleCancel
    [int]$VisionAutoDrawState

    # Sensors (ultrasonic_msg)
    [int]$UltrasonicLeftFront
    [int]$UltrasonicMiddle
    [int]$UltrasonicRightFront

    # Wireless charging (wireless_recharge)
    [int]$WirelessChargeState
    [double]$WirelessChargeVoltage
    [double]$WirelessChargeCurrent
    [int]$WirelessChargeErrorCode

    # LED (led, LedInfoMSG, HeadMsg.head_led_brightness)
    [string]$LedRegister
    [object]$LedInfo
    [int]$HeadLedBrightness

    # Electric (EletricMSG)
    [double]$BrushlessMotorCurrent
    [double]$NtcTemperature
    [double]$PushPodCurrent

    # Misc / system
    [object]$BaseStatus
    [int]$GreenGrassUpdateSwitch
    [int]$IpcameraOtaSwitch
    [object]$SystemInfo
    [object]$DebugMsg

    # GPS (parsed from rtk_base_data.rover.gngga + raw)
    [nullable[double]]$Latitude
    [nullable[double]]$Longitude
    [nullable[double]]$Altitude
    [int]$FixQuality
    [string]$GnggaRaw

    # Device message timestamp (root timestamp)
    [double]$DeviceTimestamp

    # Raw
    hidden [PSCustomObject]$RawMessage

    [string] ToString() {
        return "[$($this.Timestamp.ToString('HH:mm:ss'))] Bat:$($this.BatteryCapacity)% RTK:$($this.RtkStatus) Heading:$([math]::Round($this.Heading,1))°"
    }
}
