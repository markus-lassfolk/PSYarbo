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

    # Battery (BatteryMSG)
    if ($DeviceMsg.BatteryMSG) {
        $t.BatteryCapacity = [int]($DeviceMsg.BatteryMSG.capacity)
        $t.BatteryStatus = [int]($DeviceMsg.BatteryMSG.status)
        $t.BatteryTempError = [bool]($DeviceMsg.BatteryMSG.temp_err)
        if ($null -ne $DeviceMsg.BatteryMSG.timestamp) { $t.BatteryTimestamp = [double]($DeviceMsg.BatteryMSG.timestamp) }
        $cur = $DeviceMsg.BatteryMSG.PSObject.Properties['current']; if ($cur) { $t.BatteryCurrent = [double]$cur.Value }
        $vol = $DeviceMsg.BatteryMSG.PSObject.Properties['voltage']; if ($vol) { $t.BatteryVoltage = [double]$vol.Value }
    }

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

    if ($DeviceMsg.RTKMSG) {
        $t.Heading = [double]($DeviceMsg.RTKMSG.heading)
        $t.RtkStatus = [string]($DeviceMsg.RTKMSG.status)
        $rtk = $DeviceMsg.RTKMSG.PSObject.Properties
        if ($rtk['heading_status']) { $t.RtkHeadingStatus = [int]$rtk['heading_status'].Value }
        if ($rtk['heading_dop']) { $t.RtkHeadingDop = [double]$rtk['heading_dop'].Value }
        if ($rtk['gga_atn_dis']) { $t.RtkGgaAtnDis = [double]$rtk['gga_atn_dis'].Value }
        if ($rtk['heading_atn_dis']) { $t.RtkHeadingAtnDis = [double]$rtk['heading_atn_dis'].Value }
        if ($rtk['heading_multi']) { $t.RtkHeadingMulti = [int]$rtk['heading_multi'].Value }
        if ($rtk['heading_obs']) { $t.RtkHeadingObs = [int]$rtk['heading_obs'].Value }
        if ($rtk['pre4_timestamp']) { $t.RtkPre4Timestamp = [double]$rtk['pre4_timestamp'].Value }
        if ($rtk['rtk_version']) { $t.RtkVersion = [string]$rtk['rtk_version'].Value }
        if ($rtk['sat_num']) { $t.RtkSatNum = [int]$rtk['sat_num'].Value }
        if ($rtk['timestamp']) { $t.RtkTimestamp = [double]$rtk['timestamp'].Value }
    }
    $root = $DeviceMsg.PSObject.Properties
    if ($root['combined_odom_confidence']) { $t.OdomConfidence = [double]$root['combined_odom_confidence'].Value }
    if ($root['rtcm_age']) { $t.RtcmAge = [double]$root['rtcm_age'].Value }
    if ($root['rtcm_info']) { $t.RtcmInfo = $root['rtcm_info'].Value }
    if ($DeviceMsg.rtk_base_data) {
        $rbd = $DeviceMsg.rtk_base_data.PSObject.Properties
        if ($rbd['rover']) {
            $roverProp = $rbd['rover'].Value.PSObject.Properties['heading']
            if ($roverProp) { $t.RoverHeading = [string]$roverProp.Value }
        }
        if ($rbd['base']) {
            $baseProp = $rbd['base'].Value.PSObject.Properties['gngga']
            if ($baseProp) { $t.BaseGngga = [string]$baseProp.Value }
        }
    }

    # Running status
    if ($DeviceMsg.RunningStatusMSG) {
        $t.ChuteAngle = [int]($DeviceMsg.RunningStatusMSG.chute_angle)
        $t.RainSensorData = [int]($DeviceMsg.RunningStatusMSG.rain_sensor_data)
        $run = $DeviceMsg.RunningStatusMSG.PSObject.Properties
        if ($run['chute_steering_engine_info']) { $t.ChuteSteeringEngineInfo = [int]$run['chute_steering_engine_info'].Value }
        if ($run['chute_steering_run_status']) { $t.ChuteSteeringRunStatus = [int]$run['chute_steering_run_status'].Value }
        if ($run['head_gyro_pitch']) { $t.HeadGyroPitch = [double]$run['head_gyro_pitch'].Value }
        if ($run['head_gyro_roll']) { $t.HeadGyroRoll = [double]$run['head_gyro_roll'].Value }
        if ($run['push_pod_status']) { $t.PushPodStatus = [int]$run['push_pod_status'].Value }
        if ($run['push_rod_place']) { $t.PushRodPlace = [int]$run['push_rod_place'].Value }
        if ($run['snow_pipe_run_status']) { $t.SnowPipeRunStatus = [int]$run['snow_pipe_run_status'].Value }
        if ($run['snow_roller_motor']) { $t.SnowRollerMotor = [int]$run['snow_roller_motor'].Value }
        if ($run['elec_navigation_front_right_sensor']) { $t.ElecNavigationFrontRightSensor = [int]$run['elec_navigation_front_right_sensor'].Value }
        if ($run['elec_navigation_rear_right_sensor']) { $t.ElecNavigationRearRightSensor = [int]$run['elec_navigation_rear_right_sensor'].Value }
    }

    # State
    if ($DeviceMsg.StateMSG) {
        $t.WorkingState = [int]($DeviceMsg.StateMSG.working_state)
        $t.ChargingStatus = [int]($DeviceMsg.StateMSG.charging_status)
        $t.ErrorCode = [int]($DeviceMsg.StateMSG.error_code)
        $t.IsPlanning = ([int]($DeviceMsg.StateMSG.on_going_planning) -gt 0)
        $t.IsPaused = ([int]($DeviceMsg.StateMSG.planning_paused) -gt 0)
        $t.IsRecharging = ([int]($DeviceMsg.StateMSG.on_going_recharging) -gt 0)
        $state = $DeviceMsg.StateMSG.PSObject.Properties
        if ($state['adjustangle_status']) { $t.AdjustAngleStatus = [int]$state['adjustangle_status'].Value }
        if ($state['auto_draw_waiting_state']) { $t.AutoDrawWaitingState = [int]$state['auto_draw_waiting_state'].Value }
        if ($state['en_state_led']) { $t.EnStateLed = [int]$state['en_state_led'].Value }
        if ($state['en_warn_led']) { $t.EnWarnLed = [int]$state['en_warn_led'].Value }
        if ($state['on_going_to_start_point']) { $t.OnGoingToStartPoint = ([int]$state['on_going_to_start_point'].Value -gt 0) }
        if ($state['on_mul_points']) { $t.OnMulPoints = ([int]$state['on_mul_points'].Value -gt 0) }
        if ($state['robot_follow_state']) { $t.RobotFollowState = [int]$state['robot_follow_state'].Value }
        if ($state['schedule_cancel']) { $t.ScheduleCancel = [int]$state['schedule_cancel'].Value }
        if ($state['vision_auto_draw_state']) { $t.VisionAutoDrawState = [int]$state['vision_auto_draw_state'].Value }
    }

    # Ultrasonic sensors
    if ($DeviceMsg.ultrasonic_msg) {
        $t.UltrasonicLeftFront = [int]($DeviceMsg.ultrasonic_msg.lf_dis)
        $t.UltrasonicMiddle = [int]($DeviceMsg.ultrasonic_msg.mt_dis)
        $t.UltrasonicRightFront = [int]($DeviceMsg.ultrasonic_msg.rf_dis)
    }

    # Wireless charging
    if ($DeviceMsg.wireless_recharge) {
        $t.WirelessChargeState = [int]($DeviceMsg.wireless_recharge.state)
        $t.WirelessChargeVoltage = [double]($DeviceMsg.wireless_recharge.output_voltage)
        $t.WirelessChargeCurrent = [double]($DeviceMsg.wireless_recharge.output_current)
        $t.WirelessChargeErrorCode = [int]($DeviceMsg.wireless_recharge.error_code)
    }

    # LED (led, LedInfoMSG, HeadMsg.head_led_brightness)
    if ($root['led']) { $t.LedRegister = [string]$root['led'].Value }
    if ($root['LedInfoMSG']) { $t.LedInfo = $root['LedInfoMSG'].Value }
    if ($DeviceMsg.HeadMsg) {
        $headProp = $DeviceMsg.HeadMsg.PSObject.Properties['head_led_brightness']
        if ($headProp) { $t.HeadLedBrightness = [int]$headProp.Value }
    }

    # Electric (EletricMSG)
    if ($root['EletricMSG']) {
        $elec = $root['EletricMSG'].Value.PSObject.Properties
        if ($elec['brushless_motor_current']) { $t.BrushlessMotorCurrent = [double]$elec['brushless_motor_current'].Value }
        if ($elec['ntc_temperature']) { $t.NtcTemperature = [double]$elec['ntc_temperature'].Value }
        if ($elec['push_pod_current']) { $t.PushPodCurrent = [double]$elec['push_pod_current'].Value }
    }

    # Misc (base_status, switches, system_info, DebugMsg)
    if ($root['base_status']) { $t.BaseStatus = $root['base_status'].Value }
    if ($root['green_grass_update_switch']) { $t.GreenGrassUpdateSwitch = [int]$root['green_grass_update_switch'].Value }
    if ($root['ipcamera_ota_switch']) { $t.IpcameraOtaSwitch = [int]$root['ipcamera_ota_switch'].Value }
    if ($root['system_info']) { $t.SystemInfo = $root['system_info'].Value }
    if ($root['DebugMsg']) { $t.DebugMsg = $root['DebugMsg'].Value }

    # Device message timestamp (root)
    if ($root['timestamp']) { $t.DeviceTimestamp = [double]$root['timestamp'].Value }

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

    # Head (HeadMsg, HeadSerialMsg)
    if ($DeviceMsg.HeadMsg) { $r.HeadType = [int]($DeviceMsg.HeadMsg.head_type) }
    if ($DeviceMsg.HeadSerialMsg) { $r.HeadSerialNumber = $DeviceMsg.HeadSerialMsg.head_sn }

    # Battery (BatteryMSG)
    if ($DeviceMsg.BatteryMSG) {
        $r.BatteryCapacity = [int]($DeviceMsg.BatteryMSG.capacity)
        $r.BatteryStatus = [int]($DeviceMsg.BatteryMSG.status)
        $r.BatteryTempError = [bool]($DeviceMsg.BatteryMSG.temp_err)
        if ($null -ne $DeviceMsg.BatteryMSG.timestamp) { $r.BatteryTimestamp = [double]($DeviceMsg.BatteryMSG.timestamp) }
        $cur = $DeviceMsg.BatteryMSG.PSObject.Properties['current']; if ($cur) { $r.BatteryCurrent = [double]$cur.Value }
        $vol = $DeviceMsg.BatteryMSG.PSObject.Properties['voltage']; if ($vol) { $r.BatteryVoltage = [double]$vol.Value }
    }

    # Body (BodyMsg)
    if ($DeviceMsg.BodyMsg -and $DeviceMsg.BodyMsg.PSObject.Properties["recharge_state"]) {
        $r.RechargeState = [int]($DeviceMsg.BodyMsg.recharge_state)
    }

    # State (StateMSG)
    if ($DeviceMsg.StateMSG) {
        $r.WorkingState = [int]($DeviceMsg.StateMSG.working_state)
        $r.ChargingStatus = [int]($DeviceMsg.StateMSG.charging_status)
        $r.ErrorCode = [int]($DeviceMsg.StateMSG.error_code)
        $r.MachineController = [int]($DeviceMsg.StateMSG.machine_controller)
        $r.IsPlanning = ([int]($DeviceMsg.StateMSG.on_going_planning) -gt 0)
        $r.IsPaused = ([int]($DeviceMsg.StateMSG.planning_paused) -gt 0)
        $r.IsRecharging = ([int]($DeviceMsg.StateMSG.on_going_recharging) -gt 0)
        if ($DeviceMsg.StateMSG.PSObject.Properties["adjustangle_status"]) { $r.AdjustAngleStatus = [int]($DeviceMsg.StateMSG.adjustangle_status) }
        if ($DeviceMsg.StateMSG.PSObject.Properties["auto_draw_waiting_state"]) { $r.AutoDrawWaitingState = [int]($DeviceMsg.StateMSG.auto_draw_waiting_state) }
        if ($DeviceMsg.StateMSG.PSObject.Properties["car_controller"]) { $r.CarController = [bool]($DeviceMsg.StateMSG.car_controller) }
        if ($DeviceMsg.StateMSG.PSObject.Properties["en_state_led"]) { $r.EnStateLed = [int]($DeviceMsg.StateMSG.en_state_led) }
        if ($DeviceMsg.StateMSG.PSObject.Properties["en_warn_led"]) { $r.EnWarnLed = [int]($DeviceMsg.StateMSG.en_warn_led) }
        if ($DeviceMsg.StateMSG.PSObject.Properties["on_going_to_start_point"]) { $r.OnGoingToStartPoint = ([int]($DeviceMsg.StateMSG.on_going_to_start_point) -gt 0) }
        if ($DeviceMsg.StateMSG.PSObject.Properties["on_mul_points"]) { $r.OnMulPoints = ([int]($DeviceMsg.StateMSG.on_mul_points) -gt 0) }
        if ($DeviceMsg.StateMSG.PSObject.Properties["robot_follow_state"]) { $r.RobotFollowState = [int]($DeviceMsg.StateMSG.robot_follow_state) }
        if ($DeviceMsg.StateMSG.PSObject.Properties["schedule_cancel"]) { $r.ScheduleCancel = [int]($DeviceMsg.StateMSG.schedule_cancel) }
        if ($DeviceMsg.StateMSG.PSObject.Properties["vision_auto_draw_state"]) { $r.VisionAutoDrawState = [int]($DeviceMsg.StateMSG.vision_auto_draw_state) }
    }

    # Position
    if ($DeviceMsg.CombinedOdom) {
        $r.OdometryX = [double]($DeviceMsg.CombinedOdom.x)
        $r.OdometryY = [double]($DeviceMsg.CombinedOdom.y)
        $r.OdometryPhi = [double]($DeviceMsg.CombinedOdom.phi)
    }
    if ($DeviceMsg.RTKMSG) {
        $r.Heading = [double]($DeviceMsg.RTKMSG.heading)
        $r.RtkStatus = [string]($DeviceMsg.RTKMSG.status)
        $rtk = $DeviceMsg.RTKMSG.PSObject.Properties
        if ($rtk['heading_status']) { $r.RtkHeadingStatus = [int]$rtk['heading_status'].Value }
        if ($rtk['heading_dop']) { $r.RtkHeadingDop = [double]$rtk['heading_dop'].Value }
        if ($rtk['gga_atn_dis']) { $r.RtkGgaAtnDis = [double]$rtk['gga_atn_dis'].Value }
        if ($rtk['heading_atn_dis']) { $r.RtkHeadingAtnDis = [double]$rtk['heading_atn_dis'].Value }
        if ($rtk['heading_multi']) { $r.RtkHeadingMulti = [int]$rtk['heading_multi'].Value }
        if ($rtk['heading_obs']) { $r.RtkHeadingObs = [int]$rtk['heading_obs'].Value }
        if ($rtk['pre4_timestamp']) { $r.RtkPre4Timestamp = [double]$rtk['pre4_timestamp'].Value }
        if ($rtk['rtk_version']) { $r.RtkVersion = [string]$rtk['rtk_version'].Value }
        if ($rtk['sat_num']) { $r.RtkSatNum = [int]$rtk['sat_num'].Value }
        if ($rtk['timestamp']) { $r.RtkTimestamp = [double]$rtk['timestamp'].Value }
    }
    $rootR = $DeviceMsg.PSObject.Properties
    if ($rootR['combined_odom_confidence']) { $r.OdomConfidence = [double]$rootR['combined_odom_confidence'].Value }
    if ($rootR['rtcm_age']) { $r.RtcmAge = [double]$rootR['rtcm_age'].Value }
    if ($rootR['rtcm_info']) { $r.RtcmInfo = $rootR['rtcm_info'].Value }
    if ($DeviceMsg.rtk_base_data) {
        $rbdR = $DeviceMsg.rtk_base_data.PSObject.Properties
        if ($rbdR['rover']) {
            $roverPropR = $rbdR['rover'].Value.PSObject.Properties['heading']
            if ($roverPropR) { $r.RoverHeading = [string]$roverPropR.Value }
        }
        if ($rbdR['base']) {
            $basePropR = $rbdR['base'].Value.PSObject.Properties['gngga']
            if ($basePropR) { $r.BaseGngga = [string]$basePropR.Value }
        }
    }

    # Hardware (RunningStatusMSG, led, wireless_recharge)
    if ($DeviceMsg.RunningStatusMSG) {
        $r.ChuteAngle = [int]($DeviceMsg.RunningStatusMSG.chute_angle)
        if ($DeviceMsg.RunningStatusMSG.PSObject.Properties["rain_sensor_data"]) { $r.RainSensorData = [int]($DeviceMsg.RunningStatusMSG.rain_sensor_data) }
        if ($DeviceMsg.RunningStatusMSG.PSObject.Properties["chute_steering_engine_info"]) { $r.ChuteSteeringEngineInfo = [int]($DeviceMsg.RunningStatusMSG.chute_steering_engine_info) }
        if ($DeviceMsg.RunningStatusMSG.PSObject.Properties["chute_steering_run_status"]) { $r.ChuteSteeringRunStatus = [int]($DeviceMsg.RunningStatusMSG.chute_steering_run_status) }
        if ($DeviceMsg.RunningStatusMSG.PSObject.Properties["head_gyro_pitch"]) { $r.HeadGyroPitch = [double]($DeviceMsg.RunningStatusMSG.head_gyro_pitch) }
        if ($DeviceMsg.RunningStatusMSG.PSObject.Properties["head_gyro_roll"]) { $r.HeadGyroRoll = [double]($DeviceMsg.RunningStatusMSG.head_gyro_roll) }
        if ($DeviceMsg.RunningStatusMSG.PSObject.Properties["push_pod_status"]) { $r.PushPodStatus = [int]($DeviceMsg.RunningStatusMSG.push_pod_status) }
        if ($DeviceMsg.RunningStatusMSG.PSObject.Properties["push_rod_place"]) { $r.PushRodPlace = [int]($DeviceMsg.RunningStatusMSG.push_rod_place) }
        if ($DeviceMsg.RunningStatusMSG.PSObject.Properties["snow_pipe_run_status"]) { $r.SnowPipeRunStatus = [int]($DeviceMsg.RunningStatusMSG.snow_pipe_run_status) }
        if ($DeviceMsg.RunningStatusMSG.PSObject.Properties["snow_roller_motor"]) { $r.SnowRollerMotor = [int]($DeviceMsg.RunningStatusMSG.snow_roller_motor) }
        if ($DeviceMsg.RunningStatusMSG.PSObject.Properties["elec_navigation_front_right_sensor"]) { $r.ElecNavigationFrontRightSensor = [int]($DeviceMsg.RunningStatusMSG.elec_navigation_front_right_sensor) }
        if ($DeviceMsg.RunningStatusMSG.PSObject.Properties["elec_navigation_rear_right_sensor"]) { $r.ElecNavigationRearRightSensor = [int]($DeviceMsg.RunningStatusMSG.elec_navigation_rear_right_sensor) }
    }
    if ($DeviceMsg.PSObject.Properties["led"]) { $r.LedRegister = [string]($DeviceMsg.led) }
    if ($DeviceMsg.PSObject.Properties["LedInfoMSG"]) { $r.LedInfo = $DeviceMsg.LedInfoMSG }
    if ($DeviceMsg.HeadMsg -and $DeviceMsg.HeadMsg.PSObject.Properties["head_led_brightness"]) { $r.HeadLedBrightness = [int]($DeviceMsg.HeadMsg.head_led_brightness) }
    if ($DeviceMsg.wireless_recharge) {
        $r.WirelessChargeState = [int]($DeviceMsg.wireless_recharge.state)
        $r.WirelessChargeVoltage = [double]($DeviceMsg.wireless_recharge.output_voltage)
        $r.WirelessChargeCurrent = [double]($DeviceMsg.wireless_recharge.output_current)
        $r.WirelessChargeErrorCode = [int]($DeviceMsg.wireless_recharge.error_code)
    }

    # Ultrasonic (ultrasonic_msg)
    if ($DeviceMsg.ultrasonic_msg) {
        $r.UltrasonicLeftFront = [int]($DeviceMsg.ultrasonic_msg.lf_dis)
        $r.UltrasonicMiddle = [int]($DeviceMsg.ultrasonic_msg.mt_dis)
        $r.UltrasonicRightFront = [int]($DeviceMsg.ultrasonic_msg.rf_dis)
    }

    # Device message timestamp (root)
    if ($DeviceMsg.PSObject.Properties["timestamp"]) { $r.DeviceTimestamp = [double]($DeviceMsg.timestamp) }

    # Network (route_priority)
    if ($DeviceMsg.route_priority) {
        $r.RoutePriority = @{}
        $DeviceMsg.route_priority.PSObject.Properties | ForEach-Object { $r.RoutePriority[$_.Name] = $_.Value }
    }

    # Misc / switches / system / debug
    if ($DeviceMsg.PSObject.Properties["base_status"]) { $r.BaseStatus = $DeviceMsg.base_status }
    if ($DeviceMsg.PSObject.Properties["bds"]) { $r.Bds = $DeviceMsg.bds }
    if ($DeviceMsg.PSObject.Properties["bs"]) { $r.Bs = $DeviceMsg.bs }
    if ($DeviceMsg.PSObject.Properties["green_grass_update_switch"]) { $r.GreenGrassUpdateSwitch = [int]($DeviceMsg.green_grass_update_switch) }
    if ($DeviceMsg.PSObject.Properties["ipcamera_ota_switch"]) { $r.IpcameraOtaSwitch = [int]($DeviceMsg.ipcamera_ota_switch) }
    if ($DeviceMsg.PSObject.Properties["ms"]) { $r.Ms = $DeviceMsg.ms }
    if ($DeviceMsg.PSObject.Properties["s"]) { $r.S = $DeviceMsg.s }
    if ($DeviceMsg.PSObject.Properties["sbs"]) { $r.Sbs = $DeviceMsg.sbs }
    if ($DeviceMsg.PSObject.Properties["tms"]) { $r.Tms = $DeviceMsg.tms }
    if ($DeviceMsg.PSObject.Properties["system_info"]) { $r.SystemInfo = $DeviceMsg.system_info }
    if ($DeviceMsg.PSObject.Properties["DebugMsg"]) { $r.DebugMsg = $DeviceMsg.DebugMsg }
    if ($DeviceMsg.PSObject.Properties["EletricMSG"]) {
        if ($DeviceMsg.EletricMSG.PSObject.Properties["brushless_motor_current"]) { $r.BrushlessMotorCurrent = [double]($DeviceMsg.EletricMSG.brushless_motor_current) }
        if ($DeviceMsg.EletricMSG.PSObject.Properties["ntc_temperature"]) { $r.NtcTemperature = [double]($DeviceMsg.EletricMSG.ntc_temperature) }
        if ($DeviceMsg.EletricMSG.PSObject.Properties["push_pod_current"]) { $r.PushPodCurrent = [double]($DeviceMsg.EletricMSG.push_pod_current) }
    }

    return $r
}
