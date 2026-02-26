class YarboTelemetry {
    [datetime]$Timestamp
    [string]$SerialNumber

    # Battery
    [int]$BatteryCapacity
    [int]$BatteryStatus
    [bool]$BatteryTempError

    # Position
    [double]$X
    [double]$Y
    [double]$Phi
    [double]$Heading
    [string]$RtkStatus
    [double]$RtkDop
    [double]$OdomConfidence

    # Running status
    [int]$ChuteAngle
    [int]$ChuteSteeringEngineInfo
    [double]$HeadGyroPitch
    [double]$HeadGyroRoll
    [int]$RainSensorData

    # State flags
    [int]$WorkingState
    [int]$ChargingStatus
    [int]$ErrorCode
    [bool]$IsPlanning
    [bool]$IsPaused
    [bool]$IsRecharging

    # Sensors
    [int]$UltrasonicLeftFront
    [int]$UltrasonicMiddle
    [int]$UltrasonicRightFront

    # Wireless charging
    [int]$WirelessChargeState
    [int]$WirelessChargeVoltage
    [int]$WirelessChargeCurrent
    [int]$WirelessChargeErrorCode

    # Raw
    hidden [PSCustomObject]$RawMessage

    [string] ToString() {
        return "[$($this.Timestamp.ToString('HH:mm:ss'))] Bat:$($this.BatteryCapacity)% RTK:$($this.RtkStatus) Heading:$([math]::Round($this.Heading,1))°"
    }
}
