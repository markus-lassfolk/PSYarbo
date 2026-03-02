function ConvertFrom-GnggaSentence {
    <#
    .SYNOPSIS
        Parses a GNGGA NMEA 0183 sentence into a GPS coordinate hashtable.

    .DESCRIPTION
        Accepts a raw $GNGGA or $GPGGA NMEA sentence and returns a hashtable
        with Latitude, Longitude, Altitude, and FixQuality fields.
        Returns a hashtable with null coordinates when fix quality is 0 (invalid)
        or the sentence is absent.

    .PARAMETER Sentence
        The raw NMEA sentence string (e.g. "$GNGGA,142800.10,5920.05710640,N,...").
    #>
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Sentence
    )

    $result = @{ Latitude = $null; Longitude = $null; Altitude = $null; FixQuality = 0 }

    if (-not ($Sentence.StartsWith('$GNGGA') -or $Sentence.StartsWith('$GPGGA'))) {
        return $result
    }

    # Strip NMEA checksum (*XX) if present
    if ($Sentence.Contains('*')) {
        $Sentence = $Sentence.Substring(0, $Sentence.IndexOf('*'))
    }

    $parts = $Sentence -split ','
    if ($parts.Count -lt 10) { return $result }

    $fixQuality = 0
    if ($parts[6] -match '^\d+$') { $fixQuality = [int]$parts[6] }
    $result.FixQuality = $fixQuality

    if ($fixQuality -eq 0) { return $result }

    # Latitude: DDMM.MMMM → decimal degrees
    if ($parts[2] -and $parts[3]) {
        try {
            $rawLat = $parts[2]
            $latDeg = [double]($rawLat.Substring(0, 2))
            $latMin = [double]($rawLat.Substring(2))
            $lat = $latDeg + $latMin / 60.0
            if ($parts[3].ToUpper() -eq 'S') { $lat = - $lat }
            $result.Latitude = $lat
        } catch {
            Write-Verbose "PSYarbo: Failed to parse latitude: $($_.Exception.Message)"
        }
    }

    # Longitude: DDDMM.MMMM → decimal degrees
    if ($parts[4] -and $parts[5]) {
        try {
            $rawLon = $parts[4]
            $lonDeg = [double]($rawLon.Substring(0, 3))
            $lonMin = [double]($rawLon.Substring(3))
            $lon = $lonDeg + $lonMin / 60.0
            if ($parts[5].ToUpper() -eq 'W') { $lon = - $lon }
            $result.Longitude = $lon
        } catch {
            Write-Verbose "PSYarbo: Failed to parse longitude: $($_.Exception.Message)"
        }
    }

    # Altitude (field 9)
    if ($parts.Count -gt 9 -and $parts[9] -match '^-?\d+(\.\d+)?$') {
        $result.Altitude = [double]$parts[9]
    }

    return $result
}

function Set-YarboCommonFields {
    <#
    .SYNOPSIS
        Maps common DeviceMSG fields to a target object (YarboTelemetry or YarboRobot).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal helper only mutates in-memory object; no system state change.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'CommonFields denotes the shared DeviceMSG field group; singular would be misleading.')]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$DeviceMsg,

        [Parameter(Mandatory)]
        [object]$Target
    )

    # Battery (BatteryMSG)
    if ($DeviceMsg.BatteryMSG) {
        $Target.BatteryCapacity = [int]($DeviceMsg.BatteryMSG.capacity)
        $Target.BatteryStatus = [int]($DeviceMsg.BatteryMSG.status)
        $Target.BatteryTempError = [bool]($DeviceMsg.BatteryMSG.temp_err)
        if ($null -ne $DeviceMsg.BatteryMSG.timestamp) { $Target.BatteryTimestamp = [double]($DeviceMsg.BatteryMSG.timestamp) }
        $cur = $DeviceMsg.BatteryMSG.PSObject.Properties['current']; if ($cur) { $Target.BatteryCurrent = [double]$cur.Value }
        $vol = $DeviceMsg.BatteryMSG.PSObject.Properties['voltage']; if ($vol) { $Target.BatteryVoltage = [double]$vol.Value }
    }

    # State (StateMSG)
    if ($DeviceMsg.StateMSG) {
        $Target.WorkingState = [int]($DeviceMsg.StateMSG.working_state)
        $Target.ChargingStatus = [int]($DeviceMsg.StateMSG.charging_status)
        $Target.ErrorCode = [int]($DeviceMsg.StateMSG.error_code)
        $Target.IsPlanning = ([int]($DeviceMsg.StateMSG.on_going_planning) -gt 0)
        $Target.IsPaused = ([int]($DeviceMsg.StateMSG.planning_paused) -gt 0)
        $Target.IsRecharging = ([int]($DeviceMsg.StateMSG.on_going_recharging) -gt 0)
        $state = $DeviceMsg.StateMSG.PSObject.Properties
        if ($state['adjustangle_status']) { $Target.AdjustAngleStatus = [int]$state['adjustangle_status'].Value }
        if ($state['auto_draw_waiting_state']) { $Target.AutoDrawWaitingState = [int]$state['auto_draw_waiting_state'].Value }
        if ($state['en_state_led']) { $Target.EnStateLed = [int]$state['en_state_led'].Value }
        if ($state['en_warn_led']) { $Target.EnWarnLed = [int]$state['en_warn_led'].Value }
        if ($state['on_going_to_start_point']) { $Target.OnGoingToStartPoint = ([int]$state['on_going_to_start_point'].Value -gt 0) }
        if ($state['on_mul_points']) { $Target.OnMulPoints = ([int]$state['on_mul_points'].Value -gt 0) }
        if ($state['robot_follow_state']) { $Target.RobotFollowState = [int]$state['robot_follow_state'].Value }
        if ($state['schedule_cancel']) { $Target.ScheduleCancel = [int]$state['schedule_cancel'].Value }
        if ($state['vision_auto_draw_state']) { $Target.VisionAutoDrawState = [int]$state['vision_auto_draw_state'].Value }
    }

    # RTKMSG
    if ($DeviceMsg.RTKMSG) {
        $Target.Heading = [double]($DeviceMsg.RTKMSG.heading)
        $Target.RtkStatus = [string]($DeviceMsg.RTKMSG.status)
        $rtk = $DeviceMsg.RTKMSG.PSObject.Properties
        if ($rtk['heading_status']) { $Target.RtkHeadingStatus = [int]$rtk['heading_status'].Value }
        if ($rtk['heading_dop']) { $Target.RtkHeadingDop = [double]$rtk['heading_dop'].Value }
        if ($rtk['gga_atn_dis']) { $Target.RtkGgaAtnDis = [double]$rtk['gga_atn_dis'].Value }
        if ($rtk['heading_atn_dis']) { $Target.RtkHeadingAtnDis = [double]$rtk['heading_atn_dis'].Value }
        if ($rtk['heading_multi']) { $Target.RtkHeadingMulti = [int]$rtk['heading_multi'].Value }
        if ($rtk['heading_obs']) { $Target.RtkHeadingObs = [int]$rtk['heading_obs'].Value }
        if ($rtk['pre4_timestamp']) { $Target.RtkPre4Timestamp = [double]$rtk['pre4_timestamp'].Value }
        if ($rtk['rtk_version']) { $Target.RtkVersion = [string]$rtk['rtk_version'].Value }
        if ($rtk['sat_num']) { $Target.RtkSatNum = [int]$rtk['sat_num'].Value }
        if ($rtk['timestamp']) { $Target.RtkTimestamp = [double]$rtk['timestamp'].Value }
    }
    $root = $DeviceMsg.PSObject.Properties
    if ($root['combined_odom_confidence']) { $Target.OdomConfidence = [double]$root['combined_odom_confidence'].Value }
    if ($root['rtcm_age']) { $Target.RtcmAge = [double]$root['rtcm_age'].Value }
    if ($root['rtcm_info']) { $Target.RtcmInfo = $root['rtcm_info'].Value }
    if ($DeviceMsg.rtk_base_data) {
        $rbd = $DeviceMsg.rtk_base_data.PSObject.Properties
        if ($rbd['rover']) {
            $roverProp = $rbd['rover'].Value.PSObject.Properties['heading']
            if ($roverProp) { $Target.RoverHeading = [string]$roverProp.Value }
        }
        if ($rbd['base']) {
            $baseProp = $rbd['base'].Value.PSObject.Properties['gngga']
            if ($baseProp) { $Target.BaseGngga = [string]$baseProp.Value }
        }
    }

    # RunningStatusMSG
    if ($DeviceMsg.RunningStatusMSG) {
        $Target.ChuteAngle = [int]($DeviceMsg.RunningStatusMSG.chute_angle)
        $run = $DeviceMsg.RunningStatusMSG.PSObject.Properties
        if ($run['rain_sensor_data']) { $Target.RainSensorData = [int]$run['rain_sensor_data'].Value }
        if ($run['chute_steering_engine_info']) { $Target.ChuteSteeringEngineInfo = [int]$run['chute_steering_engine_info'].Value }
        if ($run['chute_steering_run_status']) { $Target.ChuteSteeringRunStatus = [int]$run['chute_steering_run_status'].Value }
        if ($run['head_gyro_pitch']) { $Target.HeadGyroPitch = [double]$run['head_gyro_pitch'].Value }
        if ($run['head_gyro_roll']) { $Target.HeadGyroRoll = [double]$run['head_gyro_roll'].Value }
        if ($run['push_pod_status']) { $Target.PushPodStatus = [int]$run['push_pod_status'].Value }
        if ($run['push_rod_place']) { $Target.PushRodPlace = [int]$run['push_rod_place'].Value }
        if ($run['snow_pipe_run_status']) { $Target.SnowPipeRunStatus = [int]$run['snow_pipe_run_status'].Value }
        if ($run['snow_roller_motor']) { $Target.SnowRollerMotor = [int]$run['snow_roller_motor'].Value }
        if ($run['elec_navigation_front_right_sensor']) { $Target.ElecNavigationFrontRightSensor = [int]$run['elec_navigation_front_right_sensor'].Value }
        if ($run['elec_navigation_rear_right_sensor']) { $Target.ElecNavigationRearRightSensor = [int]$run['elec_navigation_rear_right_sensor'].Value }
    }

    # Ultrasonic sensors
    if ($DeviceMsg.ultrasonic_msg) {
        $Target.UltrasonicLeftFront = [int]($DeviceMsg.ultrasonic_msg.lf_dis)
        $Target.UltrasonicMiddle = [int]($DeviceMsg.ultrasonic_msg.mt_dis)
        $Target.UltrasonicRightFront = [int]($DeviceMsg.ultrasonic_msg.rf_dis)
    }

    # Wireless charging
    if ($DeviceMsg.wireless_recharge) {
        $Target.WirelessChargeState = [int]($DeviceMsg.wireless_recharge.state)
        $Target.WirelessChargeVoltage = [double]($DeviceMsg.wireless_recharge.output_voltage)
        $Target.WirelessChargeCurrent = [double]($DeviceMsg.wireless_recharge.output_current)
        $Target.WirelessChargeErrorCode = [int]($DeviceMsg.wireless_recharge.error_code)
    }

    # LED (led, LedInfoMSG, HeadMsg.head_led_brightness)
    if ($root['led']) { $Target.LedRegister = [string]$root['led'].Value }
    if ($root['LedInfoMSG']) { $Target.LedInfo = $root['LedInfoMSG'].Value }
    if ($DeviceMsg.HeadMsg) {
        $headProp = $DeviceMsg.HeadMsg.PSObject.Properties['head_led_brightness']
        if ($headProp) { $Target.HeadLedBrightness = [int]$headProp.Value }
    }

    # Electric (EletricMSG)
    if ($root['EletricMSG']) {
        $elec = $root['EletricMSG'].Value.PSObject.Properties
        if ($elec['brushless_motor_current']) { $Target.BrushlessMotorCurrent = [double]$elec['brushless_motor_current'].Value }
        if ($elec['ntc_temperature']) { $Target.NtcTemperature = [double]$elec['ntc_temperature'].Value }
        if ($elec['push_pod_current']) { $Target.PushPodCurrent = [double]$elec['push_pod_current'].Value }
    }

    # Misc (base_status, switches, system_info, DebugMsg)
    if ($root['base_status']) { $Target.BaseStatus = $root['base_status'].Value }
    if ($root['green_grass_update_switch']) { $Target.GreenGrassUpdateSwitch = [int]$root['green_grass_update_switch'].Value }
    if ($root['ipcamera_ota_switch']) { $Target.IpcameraOtaSwitch = [int]$root['ipcamera_ota_switch'].Value }
    if ($root['system_info']) { $Target.SystemInfo = $root['system_info'].Value }
    if ($root['DebugMsg']) { $Target.DebugMsg = $root['DebugMsg'].Value }

    # Device message timestamp (root)
    if ($root['timestamp']) { $Target.DeviceTimestamp = [double]$root['timestamp'].Value }
}

function ConvertTo-YarboTelemetry {
    <#
    .SYNOPSIS
        Converts a raw DeviceMSG PSCustomObject to a YarboTelemetry instance.
    #>
    [OutputType([YarboTelemetry])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$DeviceMsg,

        [Parameter()]
        [string]$SerialNumber
    )

    $t = [YarboTelemetry]::new()
    $t.Timestamp = [datetime]::UtcNow
    $t.SerialNumber = $SerialNumber
    $t.RawMessage = $DeviceMsg

    Set-YarboCommonFields -DeviceMsg $DeviceMsg -Target $t

    # Body (BodyMsg)
    if ($DeviceMsg.BodyMsg -and $DeviceMsg.BodyMsg.PSObject.Properties["recharge_state"]) {
        $t.RechargeState = [int]($DeviceMsg.BodyMsg.recharge_state)
    }

    # Position
    if ($DeviceMsg.CombinedOdom) {
        $t.X = [double]($DeviceMsg.CombinedOdom.x)
        $t.Y = [double]($DeviceMsg.CombinedOdom.y)
        $t.Phi = [double]($DeviceMsg.CombinedOdom.phi)
    }

    # GPS — parse GNGGA NMEA sentence from rtk_base_data.rover.gngga
    if ($DeviceMsg.rtk_base_data) {
        $rbdGps = $DeviceMsg.rtk_base_data.PSObject.Properties['rover']
        if ($rbdGps) {
            $gnggaProp = $rbdGps.Value.PSObject.Properties['gngga']
            if ($gnggaProp) {
                $gnggaRaw = [string]$gnggaProp.Value
                $t.GnggaRaw = $gnggaRaw
                $gps = ConvertFrom-GnggaSentence -Sentence $gnggaRaw
                $t.FixQuality = $gps.FixQuality
                $t.Latitude = $gps.Latitude
                $t.Longitude = $gps.Longitude
                $t.Altitude = $gps.Altitude
            }
        }
    }

    return $t
}

function ConvertTo-YarboRobot {
    <#
    .SYNOPSIS
        Converts a raw DeviceMSG to a YarboRobot instance.
    #>
    [OutputType([YarboRobot])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$DeviceMsg,

        [Parameter()]
        [string]$SerialNumber,

        [Parameter()]
        [string]$Broker,

        [Parameter()]
        [int]$Port
    )

    $r = [YarboRobot]::new()
    $r.SerialNumber = $SerialNumber
    $r.Broker = $Broker
    $r.Port = $Port
    $r.LastUpdated = [datetime]::UtcNow
    $r.RawMessage = $DeviceMsg

    Set-YarboCommonFields -DeviceMsg $DeviceMsg -Target $r

    # Head (HeadMsg, HeadSerialMsg)
    if ($DeviceMsg.HeadMsg) { $r.HeadType = [int]($DeviceMsg.HeadMsg.head_type) }
    if ($DeviceMsg.HeadSerialMsg) { $r.HeadSerialNumber = $DeviceMsg.HeadSerialMsg.head_sn }

    # Body (BodyMsg)
    if ($DeviceMsg.BodyMsg -and $DeviceMsg.BodyMsg.PSObject.Properties["recharge_state"]) {
        $r.RechargeState = [int]($DeviceMsg.BodyMsg.recharge_state)
    }

    # State (StateMSG) - Robot-specific fields
    if ($DeviceMsg.StateMSG) {
        $r.MachineController = [int]($DeviceMsg.StateMSG.machine_controller)
        if ($DeviceMsg.StateMSG.PSObject.Properties["car_controller"]) { $r.CarController = [bool]($DeviceMsg.StateMSG.car_controller) }
    }

    # Position
    if ($DeviceMsg.CombinedOdom) {
        $r.OdometryX = [double]($DeviceMsg.CombinedOdom.x)
        $r.OdometryY = [double]($DeviceMsg.CombinedOdom.y)
        $r.OdometryPhi = [double]($DeviceMsg.CombinedOdom.phi)
    }

    # Network (route_priority)
    if ($DeviceMsg.route_priority) {
        $r.RoutePriority = @{}
        $DeviceMsg.route_priority.PSObject.Properties | ForEach-Object { $r.RoutePriority[$_.Name] = $_.Value }
    }

    # Misc / switches / system / debug - Robot-specific fields
    if ($DeviceMsg.PSObject.Properties["bds"]) { $r.Bds = $DeviceMsg.bds }
    if ($DeviceMsg.PSObject.Properties["bs"]) { $r.Bs = $DeviceMsg.bs }
    if ($DeviceMsg.PSObject.Properties["ms"]) { $r.Ms = $DeviceMsg.ms }
    if ($DeviceMsg.PSObject.Properties["s"]) { $r.S = $DeviceMsg.s }
    if ($DeviceMsg.PSObject.Properties["sbs"]) { $r.Sbs = $DeviceMsg.sbs }
    if ($DeviceMsg.PSObject.Properties["tms"]) { $r.Tms = $DeviceMsg.tms }

    return $r
}
