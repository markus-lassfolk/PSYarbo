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

    # Battery
    if ($DeviceMsg.BatteryMSG) {
        $t.BatteryCapacity = [int]($DeviceMsg.BatteryMSG.capacity)
        $t.BatteryStatus = [int]($DeviceMsg.BatteryMSG.status)
        $t.BatteryTempError = [bool]($DeviceMsg.BatteryMSG.temp_err)
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
        if ($null -ne $DeviceMsg.RTKMSG.heading_dop) {
            $t.RtkDop = [double]($DeviceMsg.RTKMSG.heading_dop)
        }
    }

    if ($null -ne $DeviceMsg.combined_odom_confidence) {
        $t.OdomConfidence = [double]($DeviceMsg.combined_odom_confidence)
    }

    # Running status
    if ($DeviceMsg.RunningStatusMSG) {
        $t.ChuteAngle = [int]($DeviceMsg.RunningStatusMSG.chute_angle)
        $t.RainSensorData = [int]($DeviceMsg.RunningStatusMSG.rain_sensor_data)
    }

    # State
    if ($DeviceMsg.StateMSG) {
        $t.WorkingState = [int]($DeviceMsg.StateMSG.working_state)
        $t.ChargingStatus = [int]($DeviceMsg.StateMSG.charging_status)
        $t.ErrorCode = [int]($DeviceMsg.StateMSG.error_code)
        $t.IsPlanning = ([int]($DeviceMsg.StateMSG.on_going_planning) -gt 0)
        $t.IsPaused = ([int]($DeviceMsg.StateMSG.planning_paused) -gt 0)
        $t.IsRecharging = ([int]($DeviceMsg.StateMSG.on_going_recharging) -gt 0)
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
        $t.WirelessChargeVoltage = [int]($DeviceMsg.wireless_recharge.output_voltage)
        $t.WirelessChargeCurrent = [int]($DeviceMsg.wireless_recharge.output_current)
        $t.WirelessChargeErrorCode = [int]($DeviceMsg.wireless_recharge.error_code)
    }

    # GPS — parse GNGGA NMEA sentence from rtk_base_data.rover.gngga
    if ($DeviceMsg.rtk_base_data -and $DeviceMsg.rtk_base_data.rover -and $DeviceMsg.rtk_base_data.rover.gngga) {
        $gps = ConvertFrom-GnggaSentence -Sentence ([string]$DeviceMsg.rtk_base_data.rover.gngga)
        $t.FixQuality = $gps.FixQuality
        $t.Latitude = $gps.Latitude
        $t.Longitude = $gps.Longitude
        $t.Altitude = $gps.Altitude
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

    # Head
    if ($DeviceMsg.HeadMsg) { $r.HeadType = [int]($DeviceMsg.HeadMsg.head_type) }
    if ($DeviceMsg.HeadSerialMsg) { $r.HeadSerialNumber = $DeviceMsg.HeadSerialMsg.head_sn }

    # Battery
    if ($DeviceMsg.BatteryMSG) {
        $r.BatteryCapacity = [int]($DeviceMsg.BatteryMSG.capacity)
        $r.BatteryStatus = [int]($DeviceMsg.BatteryMSG.status)
    }

    # State
    if ($DeviceMsg.StateMSG) {
        $r.WorkingState = [int]($DeviceMsg.StateMSG.working_state)
        $r.ChargingStatus = [int]($DeviceMsg.StateMSG.charging_status)
        $r.ErrorCode = [int]($DeviceMsg.StateMSG.error_code)
        $r.MachineController = [int]($DeviceMsg.StateMSG.machine_controller)
        $r.IsPlanning = ([int]($DeviceMsg.StateMSG.on_going_planning) -gt 0)
        $r.IsPaused = ([int]($DeviceMsg.StateMSG.planning_paused) -gt 0)
        $r.IsRecharging = ([int]($DeviceMsg.StateMSG.on_going_recharging) -gt 0)
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
    }
    if ($null -ne $DeviceMsg.combined_odom_confidence) {
        $r.OdomConfidence = [double]($DeviceMsg.combined_odom_confidence)
    }

    # Hardware
    if ($DeviceMsg.RunningStatusMSG) { $r.ChuteAngle = [int]($DeviceMsg.RunningStatusMSG.chute_angle) }
    if ($null -ne $DeviceMsg.led) { $r.LedRegister = [string]($DeviceMsg.led) }
    if ($DeviceMsg.wireless_recharge) {
        $r.WirelessChargeVoltage = [double]($DeviceMsg.wireless_recharge.output_voltage)
        $r.WirelessChargeCurrent = [double]($DeviceMsg.wireless_recharge.output_current)
    }

    # Network
    if ($DeviceMsg.route_priority) {
        $r.RoutePriority = @{}
        $DeviceMsg.route_priority.PSObject.Properties | ForEach-Object { $r.RoutePriority[$_.Name] = $_.Value }
    }

    return $r
}
