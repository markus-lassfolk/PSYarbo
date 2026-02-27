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

    # Position / Navigation
    [double]$OdometryX
    [double]$OdometryY
    [double]$OdometryPhi
    [double]$Heading
    [int]$RtkHeadingStatus
    [string]$RtkStatus
    [double]$RtkHeadingDop
    [double]$OdomConfidence

    # Hardware (RunningStatusMSG, led, wireless_recharge)
    [int]$ChuteAngle
    [int]$RainSensorData
    [string]$LedRegister
    [int]$WirelessChargeState
    [double]$WirelessChargeVoltage
    [double]$WirelessChargeCurrent
    [int]$WirelessChargeErrorCode

    # Ultrasonic (ultrasonic_msg)
    [int]$UltrasonicLeftFront
    [int]$UltrasonicMiddle
    [int]$UltrasonicRightFront

    # Network (route_priority)
    [hashtable]$RoutePriority

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
