# Security Policy

## Supported Versions

PSYarbo is a community project under active development. Security fixes are applied to the **latest release** only.

| Version | Supported          |
| ------- | ------------------ |
| 0.x     | ✅ Latest release  |
| < 0.1   | ❌ Not supported   |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

If you discover a security vulnerability in PSYarbo, please report it privately:

1. **GitHub Private Advisory** *(preferred)*: Go to [Security → Advisories](https://github.com/markus-lassfolk/PSYarbo/security/advisories/new) and click "Report a vulnerability".

2. **Email**: If you cannot use GitHub Advisories, contact the maintainer directly. Include "[PSYarbo Security]" in the subject line.

### What to include

- A description of the vulnerability and its potential impact
- Steps to reproduce or a proof-of-concept (if safe to share)
- Affected versions
- Any suggested mitigations

### Response timeline

| Milestone                      | Target SLA |
| ------------------------------ | ---------- |
| Acknowledgement of report      | 48 hours   |
| Initial assessment             | 5 days     |
| Fix / patch (if confirmed)     | 30 days    |
| Public disclosure              | After fix is released |

## Security Considerations

PSYarbo communicates with Yarbo robot mowers over **local MQTT**. Keep the following in mind:

- **Credentials**: Never pass passwords or API keys as plain-text parameters. Use `[SecureString]` or environment variables.
- **Network**: Restrict MQTT broker access to your local network. Do not expose the broker to the internet without TLS and authentication.
- **Firmware**: Keep your Yarbo firmware up to date for the latest manufacturer security patches.
- **Module integrity**: Only install PSYarbo from the [PowerShell Gallery](https://www.powershellgallery.com/) or from signed releases on this repository.

## Scope

The following are **in scope** for security reports:

- Credential exposure or insecure credential handling in module code
- Code execution vulnerabilities (e.g. unsafe use of `Invoke-Expression`)
- Insecure defaults that could expose a user's network or device

The following are **out of scope**:

- Vulnerabilities in the Yarbo firmware or cloud service (report to Yarbo directly)
- MQTT broker configuration issues (report to your broker vendor)
- Issues only reproducible on unsupported PowerShell versions (< 7.0)
