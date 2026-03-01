<#
.SYNOPSIS
    Analyze an MQTT recording and list payload keys not exposed by any cmdlet.

.DESCRIPTION
    Reads a recording JSON (from Record-YarboMqtt.ps1 or Invoke-YarboMqttSniff -RecordPath)
    and reports which payload keys are NOT surfaced as first-class cmdlet output.
    For meaningful results, use a recording of real MQTT from your robot (not synthetic/fixture data).
    This script works without loading the full module (e.g. in CI).

.PARAMETER RecordingPath
    Path to the recording JSON file.
#>
param(
    [Parameter(Mandatory)]
    [string]$RecordingPath
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $RecordingPath)) { Write-Error "Not found: $RecordingPath"; exit 1 }

function Expand-ZlibBytes {
    param([byte[]]$Data)
    if (-not $Data -or $Data.Length -eq 0) { return $null }
    try {
        $ms = [System.IO.MemoryStream]::new($Data)
        $zlib = [System.IO.Compression.ZLibStream]::new($ms, [System.IO.Compression.CompressionMode]::Decompress)
        $reader = [System.IO.StreamReader]::new($zlib, [System.Text.Encoding]::UTF8)
        $json = $reader.ReadToEnd()
        $reader.Close(); $zlib.Dispose(); $ms.Dispose()
        return $json | ConvertFrom-Json
    } catch { return $null }
}

function Get-AllKeys {
    param([PSCustomObject]$Obj, [string]$Prefix = '')
    $keys = [System.Collections.Generic.List[string]]::new()
    if (-not $Obj) { return @() }
    foreach ($p in $Obj.PSObject.Properties) {
        $name = $p.Name
        $path = if ($Prefix) { "$Prefix.$name" } else { $name }
        $keys.Add($path)
        $val = $p.Value
        if ($val -is [PSCustomObject]) { foreach ($sub in (Get-AllKeys -Obj $val -Prefix $path)) { $keys.Add($sub) } }
        elseif ($val -is [System.Collections.IDictionary]) {
            foreach ($k in $val.Keys) { $keys.Add("$path.$k") }
        }
    }
    return @($keys)
}

# Keys we expose as first-class properties on YarboRobot / YarboTelemetry / plan_feedback / recharge_feedback / heart_beat
$ExposedKeys = @(
    'BatteryMSG.capacity', 'BatteryMSG.status', 'BatteryMSG.temp_err', 'BatteryMSG.timestamp', 'BatteryMSG.current', 'BatteryMSG.voltage',
    'BodyMsg.recharge_state',
    'CombinedOdom.x', 'CombinedOdom.y', 'CombinedOdom.phi',
    'HeadMsg.head_type', 'HeadMsg.head_led_brightness', 'HeadSerialMsg.head_sn',
    'RTKMSG.heading', 'RTKMSG.heading_status', 'RTKMSG.status', 'RTKMSG.heading_dop',
    'RTKMSG.gga_atn_dis', 'RTKMSG.heading_atn_dis', 'RTKMSG.heading_multi', 'RTKMSG.heading_obs', 'RTKMSG.pre4_timestamp', 'RTKMSG.rtk_version', 'RTKMSG.sat_num', 'RTKMSG.timestamp',
    'RunningStatusMSG.chute_angle', 'RunningStatusMSG.rain_sensor_data', 'RunningStatusMSG.chute_steering_engine_info', 'RunningStatusMSG.chute_steering_run_status',
    'RunningStatusMSG.head_gyro_pitch', 'RunningStatusMSG.head_gyro_roll', 'RunningStatusMSG.push_pod_status', 'RunningStatusMSG.push_rod_place',
    'RunningStatusMSG.snow_pipe_run_status', 'RunningStatusMSG.snow_roller_motor', 'RunningStatusMSG.elec_navigation_front_right_sensor', 'RunningStatusMSG.elec_navigation_rear_right_sensor',
    'StateMSG.working_state', 'StateMSG.charging_status', 'StateMSG.error_code', 'StateMSG.machine_controller', 'StateMSG.car_controller',
    'StateMSG.on_going_planning', 'StateMSG.planning_paused', 'StateMSG.on_going_recharging',
    'StateMSG.adjustangle_status', 'StateMSG.auto_draw_waiting_state', 'StateMSG.en_state_led', 'StateMSG.en_warn_led',
    'StateMSG.on_going_to_start_point', 'StateMSG.on_mul_points', 'StateMSG.robot_follow_state', 'StateMSG.schedule_cancel', 'StateMSG.vision_auto_draw_state',
    'combined_odom_confidence', 'led', 'route_priority', 'ultrasonic_msg.lf_dis', 'ultrasonic_msg.mt_dis', 'ultrasonic_msg.rf_dis',
    'wireless_recharge.state', 'wireless_recharge.output_voltage', 'wireless_recharge.output_current', 'wireless_recharge.error_code',
    'rtk_base_data.rover.gngga', 'rtk_base_data.rover.heading', 'rtk_base_data.base.gngga', 'timestamp',
    'rtcm_age', 'rtcm_info', 'LedInfoMSG', 'EletricMSG.brushless_motor_current', 'EletricMSG.ntc_temperature', 'EletricMSG.push_pod_current',
    'base_status', 'bds', 'bs', 'green_grass_update_switch', 'ipcamera_ota_switch', 'ms', 's', 'sbs', 'tms', 'system_info', 'DebugMsg',
    'topic', 'state', 'msg', 'data',
    'working_state', 'planId', 'areaCovered', 'duration', 'dock_id'
)
$ExposedSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($k in $ExposedKeys) { $null = $ExposedSet.Add($k) }

$raw = Get-Content -LiteralPath $RecordingPath -Raw -Encoding UTF8 | ConvertFrom-Json
$messages = @($raw.Messages)
$allSeenKeys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$byTopic = @{}

foreach ($m in $messages) {
    $topic = $m.Topic
    $suffix = if ($topic -match 'snowbot/[^/]+/(.+)$') { $Matches[1] } else { $topic }
    if (-not $byTopic[$suffix]) { $byTopic[$suffix] = [System.Collections.Generic.List[string]]::new() }
    $decoded = $null
    if ($m.PayloadBase64) {
        try {
            $bytes = [Convert]::FromBase64String($m.PayloadBase64)
            $decoded = Expand-ZlibBytes -Data $bytes
            if (-not $decoded) {
                $str = [System.Text.Encoding]::UTF8.GetString($bytes)
                if ($str.TrimStart().StartsWith('{')) { $decoded = $str | ConvertFrom-Json }
            }
        } catch { $null = $_ }
    }
    if ($decoded) {
        $keys = Get-AllKeys -Obj $decoded
        foreach ($k in $keys) { $null = $allSeenKeys.Add($k) }
        foreach ($k in $keys) { $byTopic[$suffix].Add($k) | Out-Null }
    }
}

$notExposed = [System.Collections.Generic.List[string]]::new()
foreach ($k in $allSeenKeys) {
    $covered = $false
    foreach ($exp in $ExposedSet) {
        if ($k -eq $exp -or $k.StartsWith($exp + '.') -or $exp.StartsWith($k + '.')) { $covered = $true; break }
    }
    if (-not $covered) { $notExposed.Add($k) | Out-Null }
}

Write-Host "=== MQTT recording: $RecordingPath ==="
Write-Host "Messages: $($raw.MessageCount) | Topics: $(($byTopic.Keys | Sort-Object) -join ', ')"
Write-Host ""
Write-Host "--- Payload keys NOT exposed as first-class output by any cmdlet ---"
if ($notExposed.Count -eq 0) {
    Write-Host "  (none – all seen keys are mapped to Get-YarboStatus / Get-YarboTelemetry / Watch-YarboTelemetry / connection properties)"
} else {
    $notExposed | Sort-Object | ForEach-Object { Write-Host "  $_" }
}
Write-Host ""
Write-Host "--- Note: Full DeviceMSG is always available as .RawMessage on the object from Get-YarboStatus / Get-YarboRobot ---"
