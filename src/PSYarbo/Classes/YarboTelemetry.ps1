class YarboTelemetry {
    [datetime]$Timestamp
    [string]$SerialNumber

    # Battery (BatteryMSG)
    [int]$BatteryCapacity
    [int]$BatteryStatus
    [bool]$BatteryTempError
    [double]$BatteryTimestamp

    # Body (BodyMsg)
    [int]$RechargeState

    # Position (CombinedOdom, RTKMSG, combined_odom_confidence)
    [double]$X
    [double]$Y
    [double]$Phi
    [double]$Heading
    [int]$RtkHeadingStatus
    [string]$RtkStatus
    [double]$RtkDop
    [double]$OdomConfidence

    # Running status (RunningStatusMSG)
    [int]$ChuteAngle
    [int]$ChuteSteeringEngineInfo
    [double]$HeadGyroPitch
    [double]$HeadGyroRoll
    [int]$RainSensorData

    # State (StateMSG)
    [int]$WorkingState
    [int]$ChargingStatus
    [int]$ErrorCode
    [bool]$IsPlanning
    [bool]$IsPaused
    [bool]$IsRecharging

    # Sensors (ultrasonic_msg)
    [int]$UltrasonicLeftFront
    [int]$UltrasonicMiddle
    [int]$UltrasonicRightFront

    # Wireless charging (wireless_recharge)
    [int]$WirelessChargeState
    [double]$WirelessChargeVoltage
    [double]$WirelessChargeCurrent
    [int]$WirelessChargeErrorCode

    # LED (led)
    [string]$LedRegister

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
