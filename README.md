# PSYarbo

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSYarbo.svg)](https://www.powershellgallery.com/packages/PSYarbo)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/PSYarbo.svg)](https://www.powershellgallery.com/packages/PSYarbo)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub Issues](https://img.shields.io/github/issues/markus-lassfolk/PSYarbo.svg)](https://github.com/markus-lassfolk/PSYarbo/issues)

**PSYarbo** is a PowerShell module for local, cloud-free control of [Yarbo](https://www.yarbo.com/) robots via MQTT and optional cloud REST API.

> **Protocol documentation:** [markus-lassfolk/yarbo-reversing](https://github.com/markus-lassfolk/yarbo-reversing)

---

## Compatibility

| Robot / Head | Local MQTT | Cloud REST | Notes |
|---|---|---|---|
| Yarbo G1 + Snow Blower head | ✅ Full | ✅ Full | Primary development target |
| Yarbo G1 + Mower head | ⚠️ Partial | ✅ Full | Plan start/stop work; snow-specific commands (chute, roller) not applicable |
| Other Yarbo G1 heads | ❓ Untested | ✅ Expected | Should work if robot publishes on `snowbot/+/device/` topics |

> **Note:** The MQTT topic prefix is `snowbot/` for all Yarbo G1 robots regardless of head type.
> The `SnowBlower` tag in the module reflects the primary test platform.
> Mower-specific operations (`cmd_roller`, `cmd_chute_rotate`) are no-ops on mower heads and may return an error from the robot.

---

## Requirements

- PowerShell 7.4+ (Windows, macOS, or Linux)
- Your Yarbo robot connected to the same LAN as your computer
- MQTTnet.dll (downloaded automatically by `build/Install-Dependencies.ps1`)

---

## Installation

```powershell
Install-Module -Name PSYarbo -Repository PSGallery -Scope CurrentUser
```

Or manually from this repository:

```powershell
git clone https://github.com/markus-lassfolk/PSYarbo.git
cd PSYarbo
./build/Install-Dependencies.ps1   # downloads MQTTnet.dll
Import-Module ./src/PSYarbo/PSYarbo.psd1
```

---

## Quick Start

```powershell
# Auto-discover robots on the local network
$robot = Find-Yarbo | Select-Object -First 1
Write-Host "Found: $($robot.SerialNumber) at $($robot.Broker)"

# Connect (uses the YarboRobot object from Find-Yarbo)
$conn = $robot | Connect-Yarbo

# — OR — connect directly
$conn = Connect-Yarbo -Broker <rover-ip> -SerialNumber <serial-number>

# Check status
Get-YarboStatus

# Check battery
Get-YarboBattery

# Light control
Set-YarboLight AllOn      # all LEDs on
Set-YarboLight AllOff     # all LEDs off

# Stream real-time telemetry for 60 seconds
Watch-YarboTelemetry -Duration 00:01:00

# Disconnect cleanly
Disconnect-Yarbo
```

---

## Cmdlet Reference

### Connection

| Cmdlet | Description |
|--------|-------------|
| `Find-Yarbo` | Auto-discover Yarbo robots via MQTT (DeviceMSG, data_feedback, heart_beat; aligned with [python-yarbo](https://github.com/markus-lassfolk/python-yarbo)). Returns `YarboRobot[]`. |
| `Connect-Yarbo` | Connect to a robot's MQTT broker. Returns `YarboConnection`. |
| `Disconnect-Yarbo` | Disconnect and dispose resources. |
| `Test-YarboConnection` | Test if a connection is alive. |

### Status

| Cmdlet | Description |
|--------|-------------|
| `Get-YarboStatus` | Get full robot status as `YarboRobot`. |
| `Get-YarboRobot` | Same as `Get-YarboStatus` (alias-style). |
| `Get-YarboBattery` | Battery capacity and charging status. |
| `Get-YarboFirmware` | Firmware version info. |

### Control

| Cmdlet | Description |
|--------|-------------|
| `Set-YarboLight` | Control LED channels (presets: `AllOn`, `AllOff`, `HeadOnly`, `BodyOnly`, `TailOnly`). |
| `Start-YarboBuzzer` | Trigger the buzzer. |
| `Stop-YarboBuzzer` | Stop the buzzer. |
| `Start-YarboPlan` | Start a mowing/snow-clearing plan by ID. |
| `Stop-YarboPlan` | Stop an active plan. |
| `Suspend-YarboPlan` | Pause an active plan. |
| `Resume-YarboPlan` | Resume a paused plan. |
| `Resume-Yarbo` | Resume the robot from sleep/pause. |
| `Suspend-Yarbo` | Send the robot to sleep. |
| `Send-YarboCommand` | Send an arbitrary raw command (advanced). |

### Manual Drive *(Snow Blower head only)*

| Cmdlet | Description |
|--------|-------------|
| `Start-YarboManualDrive` | Enter manual drive mode. |
| `Set-YarboVelocity` | Set linear and angular velocity. |
| `Set-YarboRoller` | Set roller (auger) speed. |
| `Set-YarboChute` | Set chute rotation speed/velocity. |
| `Stop-YarboManualDrive` | Exit manual drive mode. |

### Plans & Maps

| Cmdlet | Description |
|--------|-------------|
| `Get-YarboPlan` | List saved plans. |
| `New-YarboPlan` | Create a new plan. |
| `Remove-YarboPlan` | Delete a plan. |
| `Get-YarboMap` | Get map data. |
| `Get-YarboSchedule` | Get scheduled plans. |
| `Set-YarboSchedule` | Update a schedule. |

### Telemetry

| Cmdlet | Description |
|--------|-------------|
| `Get-YarboTelemetry` | Get a single telemetry snapshot. |
| `Watch-YarboTelemetry` | Stream real-time telemetry (Ctrl+C to stop). |
| `Export-YarboTelemetry` | Export telemetry to CSV/JSON/JSONL. |

### Cloud

| Cmdlet | Description |
|--------|-------------|
| `Connect-YarboCloud` | Authenticate with the Yarbo cloud. |
| `Get-YarboDevice` | List robots bound to your account. |
| `Get-YarboVideo` | Get video token/URL. |
| `Get-YarboPlanHistory` | Get plan execution history from cloud. |

---

## Protocol

PSYarbo uses the `snowbot/{SN}/...` MQTT topic hierarchy discovered by reverse engineering. Payloads are zlib-compressed UTF-8 JSON. Full documentation:

👉 **[markus-lassfolk/yarbo-reversing](https://github.com/markus-lassfolk/yarbo-reversing)**

See also: `Get-Help about_PSYarbo_MQTT`

**Discovery:** Find-Yarbo and Find-YarboDevice use the same strategy as [python-yarbo](https://github.com/markus-lassfolk/python-yarbo): anonymous MQTT client, subscribe to `snowbot/+/device/DeviceMSG`, `snowbot/+/device/data_feedback`, and `snowbot/+/device/heart_beat`, and derive the robot serial number from the first message received. By default, discovery scans all networks this machine has an IP on; pass `-Subnet` (e.g. `192.0.2.0/24`) if you want to limit the scan. If discovery finds no robots, run from a host on the same LAN as the Yarbo and ensure the robot is powered and connected.

---

## Contributing

1. Fork the repo
2. Create a feature branch
3. Add Pester tests for new cmdlets
4. `Invoke-Pester` — all tests must pass
5. Open a PR

---

## License

[MIT](LICENSE) © Markus Lassfolk
