# GitHub Copilot Instructions for PSYarbo

## Project Context

PSYarbo is a PowerShell module for local control of Yarbo robotic mowers via MQTT.
Language: PowerShell (primary), Pester (tests).
Target runtime: Windows PowerShell 5.1 and PowerShell 7+.

## Code Review Guidelines

When reviewing pull requests, please focus on:

1. **PowerShell best practices** — Use approved verbs, follow PSScriptAnalyzer rules
2. **Error handling** — All functions should have try/catch and meaningful error messages
3. **MQTT correctness** — Validate topic structure and payload format against Yarbo protocol
4. **Pester tests** — New functions must have corresponding Pester tests
5. **Security** — No credentials or sensitive data in code or comments
6. **Backward compatibility** — Don't break existing cmdlet parameters

## Review Behavior

- Leave review comments with suggestions as inline code blocks
- Do NOT create new branches or PRs — only comment on existing PRs
- Do NOT auto-commit suggested changes — leave them as suggestions for the author
- Focus on correctness and security, not style nit-picks

## Module Structure

- `Public/` — Exported cmdlets (one per file, named after the cmdlet)
- `Private/` — Internal helper functions
- `Tests/` — Pester test files (mirror Public/ structure)
- `docs/` — Documentation and GitHub Pages

## MQTT Topics

Yarbo uses a specific MQTT topic structure. When reviewing MQTT-related code,
ensure topics follow the pattern: `yarbo/{device_id}/{command}`.
