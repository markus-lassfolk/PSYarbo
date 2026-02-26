# PSYarbo

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSYarbo.svg)](https://www.powershellgallery.com/packages/PSYarbo)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/PSYarbo.svg)](https://www.powershellgallery.com/packages/PSYarbo)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub Issues](https://img.shields.io/github/issues/markus-lassfolk/PSYarbo.svg)](https://github.com/markus-lassfolk/PSYarbo/issues)

**PSYarbo** is a PowerShell module for local, cloud-free control of [Yarbo](https://www.yarbo.com/) robot mowers via MQTT.

Inspired by the naming conventions of [`PSFalcon`](https://github.com/CrowdStrike/psfalcon), [`PSTeams`](https://github.com/EvotecIT/PSTeams), and [`PSSlack`](https://github.com/RamblingCookieMonster/PSSlack).

> **Protocol documentation:** [markus-lassfolk/yarbo-reversing](https://github.com/markus-lassfolk/yarbo-reversing)

---

## Requirements

- PowerShell 7.2+ (Windows, macOS, or Linux)
- An MQTT broker reachable on your LAN (EMQX or Mosquitto)
- Your Yarbo robot connected to the same network

---

## Installation

```powershell
Install-Module -Name PSYarbo -Repository PSGallery -Scope CurrentUser
```

Or manually from this repository:

```powershell
git clone https://github.com/markus-lassfolk/PSYarbo.git
Import-Module ./PSYarbo/PSYarbo.psd1
```

---

## Quick Start

```powershell
# Import the module
Import-Module PSYarbo

# Connect to your local MQTT broker
$broker = Connect-Yarbo -Host "192.168.1.24" -Port 1883

# Discover all Yarbo robots on the broker
$robots = Find-YarboRobot -Broker $broker -Timeout 5
Write-Host "Found $($robots.Count) robot(s)"

# Select the first robot
$robot = $robots[0]
Write-Host "Robot serial: $($robot.Serial)"

# Get current status
$status = Get-YarboStatus -Robot $robot
Write-Host "Battery:  $($status.BatteryPct)%"
Write-Host "State:    $($status.State)"         # Mowing / Docked / Charging / Error
Write-Host "Zone:     $($status.ActiveZone)"
Write-Host "Position: $($status.GpsLat), $($status.GpsLon)"

# Control the work light
Set-YarboLight -Robot $robot -On $true    # light on
Start-Sleep -Seconds 2
Set-YarboLight -Robot $robot -On $false   # light off

# Trigger the buzzer
Invoke-YarboBuzzer -Robot $robot

# Start mowing / return to dock
# Start-YarboMow -Robot $robot
# Stop-YarboMow -Robot $robot   # returns to dock

# Disconnect
Disconnect-Yarbo -Broker $broker
```

---

## Cmdlet Reference

### Connection

| Cmdlet | Description |
|--------|-------------|
| `Connect-Yarbo` | Connect to your local MQTT broker. Returns a `YarboBroker` object. |
| `Disconnect-Yarbo` | Disconnect cleanly from the broker. |

### Discovery

| Cmdlet | Description |
|--------|-------------|
| `Find-YarboRobot` | Scan the broker for Yarbo MQTT topics and return `YarboRobot[]` |

### Status & Telemetry

| Cmdlet | Description |
|--------|-------------|
| `Get-YarboStatus` | Fetch the latest telemetry as a `YarboStatus` object |
| `Watch-YarboTelemetry` | Stream real-time telemetry to the pipeline (Ctrl+C to stop) |

### Control

| Cmdlet | Description |
|--------|-------------|
| `Set-YarboLight` | Turn the work light on or off (`-On $true/$false`) |
| `Invoke-YarboBuzzer` | Trigger the audible buzzer |
| `Start-YarboMow` | Start mowing (optionally `-Zone <name>`) |
| `Stop-YarboMow` | Stop mowing and return to dock |

---

## Status Object Fields

```powershell
$status = Get-YarboStatus -Robot $robot
$status | Select-Object BatteryPct, State, ActiveZone, GpsLat, GpsLon, ErrorCode
```

| Property | Type | Description |
|----------|------|-------------|
| `BatteryPct` | `int` | Battery level (0–100) |
| `State` | `string` | `Mowing`, `Docked`, `Charging`, `Error`, `Returning` |
| `ActiveZone` | `string` | Active mowing zone name (or `$null`) |
| `GpsLat` | `double` | GPS latitude (or `$null`) |
| `GpsLon` | `double` | GPS longitude (or `$null`) |
| `ErrorCode` | `int` | Error code (0 = no error) |
| `Raw` | `hashtable` | Full decoded telemetry payload |

---

## Protocol

Yarbo robots communicate over MQTT with zlib-compressed JSON payloads:

```
yarbo/{serial}/heart_beat        ← telemetry (compressed)
yarbo/{serial}/command/set       ← commands
yarbo/{serial}/command/response  ← ACKs
```

Full protocol documentation is in:

👉 **[markus-lassfolk/yarbo-reversing](https://github.com/markus-lassfolk/yarbo-reversing)**

---

## Contributing

1. Fork the repo
2. Create a feature branch
3. Add Pester tests for new cmdlets
4. Open a PR

---

## License

[MIT](LICENSE) © Markus Lassfolk
