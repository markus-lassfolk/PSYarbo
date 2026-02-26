class YarboRobot {
    # Identity
    [string]$SerialNumber
    [string]$HeadSerialNumber
    [string]$Name
    [int]$HeadType

    # Battery
    [int]$BatteryCapacity
    [int]$BatteryStatus

    # State
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
    [string]$RtkStatus
    [double]$OdomConfidence

    # Hardware
    [int]$ChuteAngle
    [string]$LedRegister
    [double]$WirelessChargeVoltage
    [double]$WirelessChargeCurrent

    # Network
    [hashtable]$RoutePriority

    # Timestamps
    [datetime]$LastUpdated

    # Connection reference (hidden)
    hidden [string]$Broker
    hidden [int]$Port

    [string] ToString() {
        $name = if ($this.Name) { $this.Name } else { $this.SerialNumber }
        return "$name ($($this.SerialNumber)) - Battery: $($this.BatteryCapacity)% - State: $(if($this.WorkingState){'Active'}else{'Idle'})"
    }
}
