# Contributing to PSYarbo

Thanks for your interest in contributing! PSYarbo is a small community module, so keep it friendly and pragmatic.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Branch Strategy](#branch-strategy)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Tests](#tests)
- [Pull Request Process](#pull-request-process)
- [Releasing](#releasing)

---

## Code of Conduct

Be kind. This is a one-person community project — contributions are welcome but there are no guarantees of response time.

---

## Getting Started

### Prerequisites

- PowerShell 7.0+
- [Pester](https://pester.dev/) v5+ — `Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser`
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) v1.21+ — `Install-Module PSScriptAnalyzer -MinimumVersion 1.21.0 -Scope CurrentUser`
- [Git](https://git-scm.com/)

### Fork & clone

```bash
gh repo fork markus-lassfolk/PSYarbo --clone
cd PSYarbo
```

### Import the module locally

```powershell
Import-Module ./src/PSYarbo/PSYarbo.psd1 -Force
```

---

## Branch Strategy

| Branch          | Purpose                                      |
| --------------- | -------------------------------------------- |
| `main`          | Release-ready code. Protected. Tag = release.|
| `develop`       | Integration branch. All PRs target here.     |
| `feature/*`     | New features — branch from `develop`.        |
| `fix/*`         | Bug fixes — branch from `develop`.           |
| `docs/*`        | Documentation-only changes.                  |
| `chore/*`       | Tooling, CI, dependency updates.             |

**Always branch from `develop`**, not `main`.

```bash
git checkout develop
git pull origin develop
git checkout -b feature/my-new-cmdlet
```

---

## Development Workflow

1. Make your changes under `src/PSYarbo/`
   - Public (exported) functions go in `src/PSYarbo/Public/`
   - Private (internal) helpers go in `src/PSYarbo/Private/`
2. Write or update tests in `tests/`
3. Run lint and tests locally before pushing:

```powershell
# Lint
Invoke-ScriptAnalyzer -Path ./src -Settings ./PSScriptAnalyzerSettings.psd1 -Severity Error,Warning -Recurse

# Tests
Invoke-Pester ./tests -Output Detailed
```

4. Update `CHANGELOG.md` under `[Unreleased]`
5. Push your branch and open a PR targeting `develop`

---

## Coding Standards

### Style

- **4-space indentation**, spaces not tabs
- **LF line endings** (`.editorconfig` enforces this)
- **`Set-StrictMode -Version Latest`** in every script/module
- **`$ErrorActionPreference = 'Stop'`** at the top of scripts
- Open braces on the **same line** (`if ($x) {`)

### Naming

- Follow PowerShell [approved verbs](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
- Use `PascalCase` for functions, parameters, and variables
- Prefix private functions with `Invoke-Yarbo*` or a descriptive verb

### Comment-based help

Every exported (public) function **must** have comment-based help:

```powershell
function Connect-Yarbo {
    <#
    .SYNOPSIS
        Brief one-line description.
    .DESCRIPTION
        Longer description.
    .PARAMETER MqttServer
        MQTT broker hostname or IP.
    .EXAMPLE
        Connect-Yarbo -MqttServer '192.168.1.100'
    .NOTES
        Author: Your Name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $MqttServer
    )
    # ...
}
```

### Security

- **Never** use plain-text passwords as string parameters. Use `[SecureString]` or `[PSCredential]`.
- **Never** use `Invoke-Expression` on user-supplied strings.
- **Never** commit secrets, credentials, or IP addresses.

---

## Tests

- Tests live in `tests/`
- Use **Pester v5** syntax (`BeforeAll`, `Describe`, `Context`, `It`, `Should`)
- Every public function must have at least one test
- PSSA tests in `tests/PSScriptAnalyzer.Tests.ps1` run automatically — keep them green

### Running tests

```powershell
# All tests
Invoke-Pester ./tests -Output Detailed

# Specific file
Invoke-Pester ./tests/PSYarbo.Tests.ps1 -Output Detailed

# With NUnit output (like CI)
$config = New-PesterConfiguration
$config.Run.Path = './tests'
$config.TestResult.Enabled  = $true
$config.TestResult.OutputPath = './output/test-results/pester.xml'
Invoke-Pester -Configuration $config
```

---

## Pull Request Process

1. **Target `develop`** — never open PRs directly to `main`
2. Fill in the [PR template](.github/PULL_REQUEST_TEMPLATE.md) completely
3. Ensure all CI checks pass (lint, test, analyze)
4. Request review from `@markus-lassfolk`
5. Address all review comments before merge
6. Squash or rebase as requested by the maintainer

### Commit messages

Use the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
feat(mqtt): add Connect-Yarbo cmdlet
fix(status): handle null response from broker
docs: update README with installation steps
chore(ci): pin actions to SHA
```

---

## Releasing

Releases are tag-driven. The maintainer:

1. Merges `develop` → `main`
2. Creates a tag: `git tag v1.0.0 && git push --tags`
3. The `release.yml` workflow publishes to PSGallery and creates a GitHub Release automatically

Contributors don't need to handle releases.
