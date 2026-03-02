# Commands and Properties — Getting Information from Your Robot

This guide shows which cmdlets to use and which properties to read for status, telemetry, battery, RTK, LEDs, system info, and more.

---

## Connect first

```powershell
# Discover and connect (recommended)
$robot = Find-Yarbo | Select-Object -First 1
$conn = $robot | Connect-Yarbo

# Or connect directly if you know broker and serial number
$conn = Connect-Yarbo -Broker 192.168.1.24 -SerialNumber 24400102L8HO5227
```

After connecting, `Get-YarboStatus` and `Get-YarboTelemetry` use the current default connection unless you pass `-Connection $conn`.

---

## Status vs telemetry

| What you want | Cmdlet | Returns |
|---------------|--------|--------|
| **Full robot status** (one snapshot) | `Get-YarboStatus` or `Get-YarboRobot` | `YarboRobot` |
| **Single telemetry snapshot** | `Get-YarboTelemetry` | `YarboTelemetry` |
| **Streaming telemetry** | `Watch-YarboTelemetry -Duration 00:01:00` | Events (YarboTelemetry objects) |
| **Battery only** | `Get-YarboBattery` | Integer 0–100 |

`YarboRobot` and `YarboTelemetry` share most of the same properties (both are built from the same MQTT DeviceMSG). Use **Get-YarboStatus** when you want the full status object to inspect or script against.

---

## Getting status and storing it

```powershell
$status = Get-YarboStatus    # or: Get-YarboRobot
# $status is a YarboRobot with many properties (see below)
```

---

## Property reference

### Identity

| Property | Type | Description |
|----------|------|-------------|
| `SerialNumber` | string | Robot serial number |
| `HeadSerialNumber` | string | Attached head serial |
| `Name` | string | Robot name (if set) — **from cloud only, not MQTT** |
| `HeadType` | int | Head type identifier (0=NoHead, 1=SnowBlower, 2=LeafBlower, 3=LawnMower, 4=SmartCover, 5=LawnMowerPro, 99=Trimmer). See `Get-Help about_PSYarbo_Heads` for full list. |

**Robot name (the one you gave it):** Local MQTT does **not** provide the robot’s friendly name. That name comes from the **cloud API**. Use `Get-YarboDevice` (after `Connect-YarboCloud`) to get it; each device has a `.name` property (e.g. `"My Yarbo"`). You can match by `SerialNumber` and assign it to your status object if you want:

```powershell
Connect-YarboCloud -Email you@example.com -Password $pw
$devices = Get-YarboDevice
$status = Get-YarboStatus
$status.Name = ($devices | Where-Object { $_.sn -eq $status.SerialNumber }).name
# Now $status.Name is e.g. "My Yarbo"
```

**Example:** `$status.SerialNumber` → `24400102L8HO5227`

---

### Battery (BatteryMSG)

| Property | Type | Description |
|----------|------|-------------|
| `BatteryCapacity` | int | Charge percentage (0–100) |
| `BatteryStatus` | int | Status code |
| `BatteryTempError` | bool | Temperature error flag |
| `BatteryTimestamp` | double | Device timestamp |
| `BatteryCurrent` | double | Current (when present) |
| `BatteryVoltage` | double | Voltage (when present) |

**Examples:**

```powershell
$status.BatteryCapacity      # e.g. 83
$status.BatteryCurrent       # current draw
$status.BatteryVoltage       # voltage
Get-YarboBattery             # quick 0–100 only
```

---

### State (StateMSG)

| Property | Type | Description |
|----------|------|-------------|
| `WorkingState` | int | 0 = idle, non-zero = active |
| `ChargingStatus` | int | Charging state |
| `ErrorCode` | int | Error code (0 = none) |
| `IsPlanning` | bool | Plan in progress |
| `IsPaused` | bool | Plan paused |
| `IsRecharging` | bool | Recharge in progress |
| `CarController` | bool | Car controller flag |
| `MachineController` | int | Machine controller state |
| `AdjustAngleStatus` | int | Adjust angle state |
| `AutoDrawWaitingState` | int | Auto-draw waiting state |
| `EnStateLed` | int | State LED enable |
| `EnWarnLed` | int | Warning LED enable |
| `OnGoingToStartPoint` | bool | Going to start point |
| `OnMulPoints` | bool | Multi-point state |
| `RobotFollowState` | int | Follow state |
| `ScheduleCancel` | int | Schedule cancel state |
| `VisionAutoDrawState` | int | Vision auto-draw state |

**Examples:**

```powershell
$status.WorkingState         # 0 = idle
$status.IsPlanning           # true if plan running
$status.ErrorCode            # 0 = no error
```

---

### Position / navigation (RTK, odometry)

| Property | Type | Description |
|----------|------|-------------|
| `OdometryX`, `OdometryY`, `OdometryPhi` | double | Odometry position |
| `Heading` | double | Heading (degrees) |
| `RtkHeadingStatus` | int | RTK heading status |
| `RtkStatus` | string | RTK status string |
| `RtkHeadingDop` | double | Heading DOP |
| `OdomConfidence` | double | Odometry confidence |
| `RtkGgaAtnDis` | double | GGA attenuation |
| `RtkHeadingAtnDis` | double | Heading attenuation |
| `RtkHeadingMulti` | int | Heading multi |
| `RtkHeadingObs` | int | Heading observations |
| `RtkPre4Timestamp` | double | Pre4 timestamp |
| `RtkVersion` | string | RTK firmware version |
| `RtkSatNum` | int | Number of satellites |
| `RtkTimestamp` | double | RTK timestamp |
| `RtcmAge` | double | RTCM age |
| `RtcmInfo` | object | RTCM info (nested) |
| `RoverHeading` | string | Rover heading from rtk_base_data |
| `BaseGngga` | string | Base station GNGGA sentence |

**Examples:**

```powershell
$status.Heading              # e.g. 339.45
$status.RtkStatus            # e.g. "4"
$status.RtkVersion           # RTK version string
$status.RtkSatNum            # satellite count
$tel = Get-YarboTelemetry
$tel.RtkSatNum
$tel.RoverHeading
```

---

### Hardware (RunningStatusMSG, LED, wireless charge)

| Property | Type | Description |
|----------|------|-------------|
| `ChuteAngle` | int | Chute angle (snow blower) |
| `RainSensorData` | int | Rain sensor value |
| `ChuteSteeringEngineInfo` | int | Chute steering engine |
| `ChuteSteeringRunStatus` | int | Chute run status |
| `HeadGyroPitch` | double | Head gyro pitch |
| `HeadGyroRoll` | double | Head gyro roll |
| `PushPodStatus` | int | Push pod status |
| `PushRodPlace` | int | Push rod place |
| `SnowPipeRunStatus` | int | Snow pipe run status |
| `SnowRollerMotor` | int | Snow roller motor |
| `ElecNavigationFrontRightSensor` | int | Nav sensor front-right |
| `ElecNavigationRearRightSensor` | int | Nav sensor rear-right |
| `LedRegister` | string | Raw LED register value |
| `LedInfo` | object | LED info (body_left_r/g/b, body_right_*, led_head, led_left_w, led_right_w, tail_left_r, tail_right_r) |
| `HeadLedBrightness` | int | Head LED brightness |
| `WirelessChargeState` | int | Wireless charge state |
| `WirelessChargeVoltage` | double | Charge voltage |
| `WirelessChargeCurrent` | double | Charge current |
| `WirelessChargeErrorCode` | int | Charge error code |
| `BrushlessMotorCurrent` | double | Brushless motor current (EletricMSG) |
| `NtcTemperature` | double | NTC temperature |
| `PushPodCurrent` | double | Push pod current |

**Examples:**

```powershell
$status.ChuteAngle
$status.LedInfo.led_head
$status.LedInfo.body_left_r
$status.HeadLedBrightness
$tel = Get-YarboTelemetry
$tel.ChuteSteeringRunStatus
$tel.HeadGyroPitch
```

---

### Ultrasonic sensors

| Property | Type |
|----------|------|
| `UltrasonicLeftFront` | int |
| `UltrasonicMiddle` | int |
| `UltrasonicRightFront` | int |

**Example:** `$status.UltrasonicLeftFront`

---

### Network and misc

| Property | Type | Description |
|----------|------|-------------|
| `RoutePriority` | hashtable | Route priority (e.g. hg0, wlan0, wwan0) |
| `BaseStatus` | object | base_status payload |
| `Bds`, `Bs`, `Ms`, `S`, `Sbs`, `Tms` | object | Misc MQTT fields (when present) |
| `GreenGrassUpdateSwitch` | int | Green grass update switch |
| `IpcameraOtaSwitch` | int | IPC camera OTA switch |
| `SystemInfo` | object | system_info (cpu.Frequency, cpu.Temperature, cpu.Usage, mem.*, userdata.disk.*, topProc) |
| `DebugMsg` | object | Debug message payload |
| `DeviceTimestamp` | double | Device message timestamp |
| `LastUpdated` | datetime | When we last updated this object |

**Examples:**

```powershell
$status.SystemInfo.cpu.Temperature
$status.SystemInfo.cpu.Usage
$status.SystemInfo.mem.MemAvailable
$status.SystemInfo.userdata.disk.availableSize
$status.RoutePriority.wlan0
```

---

### YarboTelemetry-only (position as X/Y/Phi)

`Get-YarboTelemetry` returns a `YarboTelemetry` object. It has the same MQTT-derived properties as above, plus:

| Property | Type | Description |
|----------|------|-------------|
| `Timestamp` | datetime | When the snapshot was taken |
| `X`, `Y`, `Phi` | double | Position (CombinedOdom) |
| `Latitude`, `Longitude`, `Altitude` | double? | Parsed from GPS (rtk_base_data.rover.gngga) |
| `FixQuality` | int | GPS fix quality |
| `GnggaRaw` | string | Raw GNGGA NMEA sentence |

**Example:**

```powershell
$tel = Get-YarboTelemetry
$tel.X
$tel.Latitude
$tel.GnggaRaw
```

---

## Full MQTT payload (RawMessage)

Every property above is taken from the robot’s MQTT DeviceMSG. The **entire** decoded payload is also available so you can access any field that isn’t mapped to a typed property:

```powershell
$status = Get-YarboStatus
$status.RawMessage           # full DeviceMSG PSCustomObject
$status.RawMessage.SomeKey   # any key from the JSON
```

---

## Example snippets

```powershell
# Connect and get status
$robot = Find-Yarbo | Select-Object -First 1
$robot | Connect-Yarbo | Out-Null
$status = Get-YarboStatus

# Battery and basic state
$status.BatteryCapacity
$status.BatteryCurrent
$status.BatteryVoltage
$status.WorkingState

# RTK / GPS
$status.RtkVersion
$status.RtkSatNum
$status.Heading
$status.RtcmAge

# System (CPU, memory, disk)
$status.SystemInfo.cpu.Temperature
$status.SystemInfo.cpu.Usage
$status.SystemInfo.mem.MemAvailable
$status.SystemInfo.userdata.disk.availableSize

# LEDs
$status.LedInfo.led_head
$status.LedInfo.body_left_r
$status.HeadLedBrightness

# Telemetry snapshot (same kind of properties)
$tel = Get-YarboTelemetry
$tel.RtkSatNum
$tel.ChuteSteeringRunStatus
$tel.BatteryCurrent
```

---

## Recording MQTT and checking coverage

To record real MQTT from your robot and see which topics map to which cmdlets:

```powershell
.\tools\Record-YarboMqtt.ps1 -DiscoverBroker
# Or with a known broker:
.\tools\Record-YarboMqtt.ps1 -Broker 192.168.1.24 -DurationSeconds 60
```

Then open the generated report or run:

```powershell
Get-YarboMqttRecordingReport -RecordingPath .\PSYarbo-MqttRecording-<timestamp>.json
```

See [README](https://github.com/markus-lassfolk/PSYarbo/blob/main/README.md) for full cmdlet lists and installation.

---

## Robot offline or sleeping — what MQTT info do we get?

The MQTT broker runs **on the robot**. What you get depends on whether the robot is reachable and whether it is awake or sleeping.

### Robot completely offline (powered off or not on the network)

- **No MQTT at all.** There is no broker to connect to.
- `Find-Yarbo` / `Find-YarboDevice` will not return this robot (no TCP, or TCP works but no `heart_beat`/DeviceMSG).
- `Connect-Yarbo` will fail (TCP connect timeout or connection refused).
- **You get:** no connection, no status, no telemetry. Use your network tools or cloud app to confirm the robot is on and on the same LAN.

### Robot “sleeping” (suspended / low power, broker still reachable)

If the robot is in sleep mode (e.g. after `Suspend-Yarbo` or auto-sleep), the broker may still accept TCP connections and subscriptions, but the robot often **stops or greatly reduces** publishing:

- **device/DeviceMSG** — full status (battery, RTK, state, etc.) — typically **not published** while sleeping.
- **device/heart_beat** — simple keepalive with `working_state` — may stop or be rare.

So in practice:

- You **can** often still **connect** (`Connect-Yarbo` succeeds).
- **get_controller** usually **times out** (robot not responding). You get a warning and the connection is left in **Connected** state without **ControllerAcquired**.
- **No new DeviceMSG** (and possibly no new heart_beat) until the robot wakes.
- Commands that send a request and wait for a response (e.g. `Get-YarboStatus` → get_device_msg) will **time out**; you do **not** get fresh status from MQTT.

**What you *do* get in this situation:**

| Source | What you get |
|--------|-------------------------------|
| **Connection object** | `State` = Connected, `ControllerAcquired` = false, `Broker`, `SerialNumber`, `ConnectedAt`. |
| **LastHeartbeat** | Last time a `heart_beat` was received (or `DateTime.MinValue` if none). Stale once the robot is asleep. |
| **LastWorkingState** | `working_state` from that last heart_beat (0 = idle/sleep). |
| **Connection.Robot** | Only if at least one **DeviceMSG** was received earlier (e.g. before sleep). That last snapshot is stale. |
| **Get-YarboStatus** | Times out (no response to get_device_msg). No new data. |
| **Test-YarboConnection -Detailed** | `Connected` (MQTT client still connected), `HeartbeatAge` (time since last heart_beat), `ControllerAcquired` = false. |

**Example: check if the robot is likely sleeping**

```powershell
$conn = $conn ?? (Get-YarboConnection)   # your connection
$detail = Test-YarboConnection -Connection $conn -Detailed
$detail.Connected          # true = MQTT still connected
$detail.ControllerAcquired # false = we don't have controller (often means robot sleeping)
$detail.HeartbeatAge       # time since last heart_beat (e.g. 00:05:00 = 5 minutes)
$conn.LastWorkingState     # 0 = idle/sleep when we last heard
# If HeartbeatAge is large and ControllerAcquired is false → robot probably sleeping
Resume-Yarbo -Connection $conn   # wake the robot, then retry Get-YarboStatus
```

### Summary

| Robot state | MQTT connection | New DeviceMSG / status | What you can use |
|-------------|-----------------|------------------------|------------------|
| **Offline** (off or not on LAN) | No | No | Nothing; fix network/power. |
| **Sleeping** (broker up, robot not responding) | Yes (usually) | No (timeouts) | Connection metadata, last `Robot` if any, `Test-YarboConnection -Detailed`, `Resume-Yarbo` to wake. |
| **Active** | Yes | Yes | Full status and telemetry as in the rest of this doc. |

---

## Debug logging and support bundles

To see exactly what is sent and received over MQTT (e.g. for unsupported firmware or heads):

- Use **`-Debug`** on any MQTT cmdlet, or set **`$env:PSYARBO_DEBUG = "1"`** for the whole session. Set **`$env:PSYARBO_DEBUG_RAW = "1"`** for raw (base64) payloads instead of JSON.
- Use **`Export-YarboSupportBundle -Path ./bundle.json -RecordingPath ./recording.json`** (and/or **`-Connection $conn`**) to produce a redacted JSON file you can attach to an issue or upload to GlitchTip. See README section *Debug logging and support bundles*.
