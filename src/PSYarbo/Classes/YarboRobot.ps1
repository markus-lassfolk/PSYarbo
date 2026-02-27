class YarboRobot {
    # Identity
    [string]$SerialNumber
    [string]$HeadSerialNumber
    [string]$Name
    [int]$HeadType

    # Battery (BatteryMSG)
    [int]$BatteryCapacity
    [int]$BatteryStatus
    [bool]$BatteryTempError
    [double]$BatteryTimestamp
    [double]$BatteryCurrent
    [double]$BatteryVoltage

    # Body (BodyMsg)
    [int]$RechargeState

    # State (StateMSG)
    [int]$WorkingState
    [int]$ChargingStatus
    [int]$ErrorCode
    [bool]$IsPlanning
    [bool]$IsPaused
    [bool]$IsRecharging
    [bool]$CarController
    [int]$MachineController
    [int]$AdjustAngleStatus
    [int]$AutoDrawWaitingState
    [int]$EnStateLed
    [int]$EnWarnLed
    [bool]$OnGoingToStartPoint
    [bool]$OnMulPoints
    [int]$RobotFollowState
    [int]$ScheduleCancel
    [int]$VisionAutoDrawState

    # Position / Navigation
    [double]$OdometryX
    [double]$OdometryY
    [double]$OdometryPhi
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

    # Hardware (RunningStatusMSG, led, wireless_recharge)
    [int]$ChuteAngle
    [int]$RainSensorData
    [int]$ChuteSteeringEngineInfo
    [int]$ChuteSteeringRunStatus
    [double]$HeadGyroPitch
    [double]$HeadGyroRoll
    [int]$PushPodStatus
    [int]$PushRodPlace
    [int]$SnowPipeRunStatus
    [int]$SnowRollerMotor
    [int]$ElecNavigationFrontRightSensor
    [int]$ElecNavigationRearRightSensor
    [string]$LedRegister
    [object]$LedInfo
    [int]$HeadLedBrightness
    [int]$WirelessChargeState
    [double]$WirelessChargeVoltage
    [double]$WirelessChargeCurrent
    [int]$WirelessChargeErrorCode
    # Electric (EletricMSG)
    [double]$BrushlessMotorCurrent
    [double]$NtcTemperature
    [double]$PushPodCurrent

    # Ultrasonic (ultrasonic_msg)
    [int]$UltrasonicLeftFront
    [int]$UltrasonicMiddle
    [int]$UltrasonicRightFront

    # Network (route_priority)
    [hashtable]$RoutePriority

    # Switches / misc (base_status, bds, bs, ms, s, sbs, tms)
    [object]$BaseStatus
    [object]$Bds
    [object]$Bs
    [int]$GreenGrassUpdateSwitch
    [int]$IpcameraOtaSwitch
    [object]$Ms
    [object]$S
    [object]$Sbs
    [object]$Tms

    # System info (system_info: cpu, mem, userdata)
    [object]$SystemInfo

    # Debug (DebugMsg)
    [object]$DebugMsg

    # Timestamps (device timestamp + our LastUpdated)
    [double]$DeviceTimestamp
    [datetime]$LastUpdated

    # Connection reference (hidden)
    hidden [string]$Broker
    hidden [int]$Port

    # Full DeviceMSG payload (all MQTT keys available)
    hidden [PSCustomObject]$RawMessage

    [string] ToString() {
        $displayName = if ($this.Name) { $this.Name } else { $this.SerialNumber }
        return "$displayName ($($this.SerialNumber)) - Battery: $($this.BatteryCapacity)% - State: $(if($this.WorkingState){'Active'}else{'Idle'})"
    }
}
