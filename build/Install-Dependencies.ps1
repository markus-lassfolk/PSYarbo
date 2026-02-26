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

# SHA256 hashes for known-good NuGet packages.
# To update: run `Get-FileHash <downloaded.nupkg> -Algorithm SHA256` after downloading from NuGet.
$knownHashes = @{
    '4.3.7.1207' = 'D574570FD2B3B538891968CE8CD05678FDBA395DFF8DB0995854ADEC6B79637C'
}

Write-Host "Downloading MQTTnet $Version..." -ForegroundColor Cyan

# Create lib directory
New-Item -ItemType Directory -Path $libDir -Force | Out-Null

# Download NuGet package
$nupkgUrl = "https://www.nuget.org/api/v2/package/MQTTnet/$Version"
$nupkgPath = Join-Path $tempDir "MQTTnet.$Version.nupkg"

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Invoke-WebRequest -Uri $nupkgUrl -OutFile $nupkgPath

# Verify SHA256 hash to guard against supply-chain tampering
if ($knownHashes.ContainsKey($Version)) {
    $expectedHash = $knownHashes[$Version]
    $actualHash = (Get-FileHash -Path $nupkgPath -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        throw ("SHA256 mismatch for MQTTnet $Version nupkg!`n" +
            "  Expected : $expectedHash`n" +
            "  Actual   : $actualHash`n" +
            "Download may be corrupted or tampered. Aborting.")
    }
    Write-Host "✓ SHA256 hash verified for MQTTnet $Version" -ForegroundColor Green
} else {
    Write-Warning ("No pinned SHA256 hash for MQTTnet $Version. " +
        "Add the expected hash to the `$knownHashes table in Install-Dependencies.ps1 for supply-chain integrity.")
}

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
