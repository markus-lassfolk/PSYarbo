#Requires -Version 7.0
<#
.SYNOPSIS
    Build script for PSYarbo. Runs lint, tests, bumps version, and packages the module.

.DESCRIPTION
    Intended to be run locally or from CI. Steps:
      1. Lint — PSScriptAnalyzer (Error + Warning)
      2. Test  — Pester v5+, NUnit XML output
      3. Build — Copy src/ to output/, stamp version from $Version param
      4. Pack  — (optional) Publish-Module to PSGallery

.PARAMETER Version
    Version to stamp into the manifest. Defaults to existing manifest version.
    When running from tag-based CI, pass the tag value (stripped of leading 'v').

.PARAMETER OutputDir
    Directory to write the built module into. Defaults to ./output/PSYarbo.

.PARAMETER Publish
    If set, publish the built module to the PowerShell Gallery.
    Requires the PSGALLERY_API_KEY environment variable.

.EXAMPLE
    ./build/build.ps1 -Version 1.0.0

.EXAMPLE
    ./build/build.ps1 -Version 1.0.0 -Publish
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Version,
    [string] $OutputDir,
    [switch] $Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path $PSScriptRoot -Parent
$srcDir     = Join-Path $repoRoot 'src' 'PSYarbo'
$testsDir   = Join-Path $repoRoot 'tests'
$outputBase = $OutputDir ? $OutputDir : (Join-Path $repoRoot 'output' 'PSYarbo')
$settings   = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Assert-ModuleAvailable {
    param([string]$Name, [string]$MinVersion)
    $m = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $m) {
        throw "Required module '$Name' is not installed. Run: Install-Module $Name -Scope CurrentUser"
    }
    if ($MinVersion -and ($m.Version -lt [version]$MinVersion)) {
        throw "Module '$Name' version $($m.Version) is below minimum $MinVersion."
    }
    Import-Module $Name -MinimumVersion $MinVersion -Force
}

#region — Pre-flight checks
Write-Step 'Pre-flight: checking required modules'
Assert-ModuleAvailable 'PSScriptAnalyzer' '1.21.0'
Assert-ModuleAvailable 'Pester' '5.0.0'
#endregion

#region — Lint
Write-Step 'Lint: PSScriptAnalyzer'
$psFiles = Get-ChildItem -Path $srcDir -Include '*.ps1', '*.psm1', '*.psd1' -Recurse |
    Where-Object { $_.Name -ne 'PSScriptAnalyzerSettings.psd1' }

$lintFindings = @()
foreach ($file in $psFiles) {
    $lintFindings += Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settings -Severity Error, Warning
}

if ($lintFindings.Count -gt 0) {
    $lintFindings | Format-Table -AutoSize
    throw "PSScriptAnalyzer found $($lintFindings.Count) issue(s). Fix them before building."
}
Write-Host '  Lint: PASSED (0 findings)' -ForegroundColor Green
#endregion

#region — Tests
Write-Step 'Test: Pester v5'
$testResultsDir = Join-Path $repoRoot 'output' 'test-results'
New-Item -ItemType Directory -Path $testResultsDir -Force | Out-Null

$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path            = $testsDir
$pesterConfig.Output.Verbosity    = 'Detailed'
$pesterConfig.TestResult.Enabled  = $true
$pesterConfig.TestResult.OutputPath   = Join-Path $testResultsDir 'pester-results.xml'
$pesterConfig.TestResult.OutputFormat = 'NUnitXml'

$result = Invoke-Pester -Configuration $pesterConfig -PassThru

if ($result.FailedCount -gt 0) {
    throw "Pester: $($result.FailedCount) test(s) failed. See output above."
}
Write-Host "  Tests: PASSED ($($result.PassedCount) passed)" -ForegroundColor Green
#endregion

#region — Build / copy
Write-Step "Build: copying module to $outputBase"

if (Test-Path $outputBase) {
    Remove-Item $outputBase -Recurse -Force
}
Copy-Item -Path $srcDir -Destination $outputBase -Recurse -Force

# Stamp version into manifest
$manifestPath = Join-Path $outputBase 'PSYarbo.psd1'
if ($Version) {
    if (-not ($Version -match '^\d+\.\d+\.\d+')) {
        throw "Version '$Version' does not match expected semver format (x.y.z)."
    }
    Write-Host "  Stamping version: $Version"
    $content = Get-Content $manifestPath -Raw
    $content = $content -replace "ModuleVersion\s*=\s*'[^']+'", "ModuleVersion     = '$Version'"
    Set-Content -Path $manifestPath -Value $content -Encoding UTF8
} else {
    $manifest = Test-ModuleManifest -Path $manifestPath
    $Version = $manifest.Version.ToString()
    Write-Host "  Using existing version: $Version"
}

Write-Host "  Build: DONE → $outputBase" -ForegroundColor Green
#endregion

#region — Publish
if ($Publish) {
    Write-Step 'Publish: PowerShell Gallery'
    $apiKey = $env:PSGALLERY_API_KEY
    if (-not $apiKey) {
        throw 'PSGALLERY_API_KEY environment variable is not set.'
    }

    if ($PSCmdlet.ShouldProcess('PowerShell Gallery', "Publish PSYarbo $Version")) {
        Publish-Module -Path $outputBase -NuGetApiKey $apiKey -Verbose
        Write-Host "  Published PSYarbo $Version to PSGallery" -ForegroundColor Green
    }
}
#endregion

Write-Host "`nBuild complete. Version: $Version" -ForegroundColor Green
