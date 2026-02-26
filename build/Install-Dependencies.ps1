<#
.SYNOPSIS
    Downloads MQTTnet from NuGet and extracts the DLL to src/PSYarbo/lib/.

.DESCRIPTION
    This script downloads the MQTTnet NuGet package and extracts the net8.0
    DLL for use with PSYarbo. Run this before importing the module.

.PARAMETER Version
    MQTTnet version to download. Default: 4.3.7.1207.

.EXAMPLE
    ./build/Install-Dependencies.ps1

.EXAMPLE
    ./build/Install-Dependencies.ps1 -Version 4.3.7.1207
#>
[CmdletBinding()]
param(
    [string]$Version = '4.3.7.1207'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$libDir = Join-Path $repoRoot 'src' 'PSYarbo' 'lib'
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "mqttnet-$Version"

Write-Host "Downloading MQTTnet $Version..." -ForegroundColor Cyan

# Create lib directory
New-Item -ItemType Directory -Path $libDir -Force | Out-Null

# Download NuGet package
$nupkgUrl = "https://www.nuget.org/api/v2/package/MQTTnet/$Version"
$nupkgPath = Join-Path $tempDir "MQTTnet.$Version.nupkg"

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Invoke-WebRequest -Uri $nupkgUrl -OutFile $nupkgPath

# Extract
$extractDir = Join-Path $tempDir 'extracted'
Expand-Archive -Path $nupkgPath -DestinationPath $extractDir -Force

# Copy net8.0 DLL
$dllSource = Join-Path $extractDir 'lib' 'net8.0' 'MQTTnet.dll'
if (-not (Test-Path $dllSource)) {
    # Fallback to netstandard2.0
    $dllSource = Join-Path $extractDir 'lib' 'netstandard2.0' 'MQTTnet.dll'
}

if (Test-Path $dllSource) {
    Copy-Item -Path $dllSource -Destination (Join-Path $libDir 'MQTTnet.dll') -Force
    Write-Host "✓ MQTTnet.dll installed to $libDir" -ForegroundColor Green
} else {
    throw "Could not find MQTTnet.dll in the NuGet package. Available files: $(Get-ChildItem $extractDir -Recurse -Name '*.dll' | Out-String)"
}

# Cleanup
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Done. MQTTnet $Version is ready." -ForegroundColor Green
