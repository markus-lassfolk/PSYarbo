# PSYarbo

**PSYarbo** is a PowerShell module for local control of Yarbo robotic mowers via MQTT — no cloud required.

## Quick Links

- 📖 [Full Documentation (README)](https://github.com/markus-lassfolk/PSYarbo/blob/main/README.md)
- 🐛 [Report a Bug](https://github.com/markus-lassfolk/PSYarbo/issues/new?template=bug_report.yml)
- 💡 [Request a Feature](https://github.com/markus-lassfolk/PSYarbo/issues/new?template=feature_request.yml)
- 💬 [Discussions](https://github.com/markus-lassfolk/PSYarbo/discussions)

## What It Does

PSYarbo lets you control your Yarbo mower directly from PowerShell over your local network using MQTT:

- 🔍 **Discover** — Auto-find Yarbo devices on your network
- 💡 **Light Control** — Turn work lights on/off
- 🔔 **Buzzer** — Trigger alerts
- 📊 **Status & Telemetry** — Query device state, battery, GPS
- ☁️ **Optional Cloud** — Fallback to cloud when needed

## Installation

```powershell
Install-Module -Name PSYarbo
```

## Milestones

| Version | Goal |
|---------|------|
| v0.1.0  | Basic MQTT connectivity and discovery |
| v0.2.0  | Light, buzzer, status, telemetry commands |
| v1.0.0  | Full local control + optional cloud |

---

*Built with ❤️ for the Yarbo community.*

