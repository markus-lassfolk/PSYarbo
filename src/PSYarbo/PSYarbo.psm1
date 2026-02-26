#Requires -Version 7.0
<#
.SYNOPSIS
    PSYarbo — PowerShell module for local control of Yarbo robot mowers via MQTT.

.DESCRIPTION
    Provides cmdlets to discover, connect to, and control Yarbo robot mowers
    on a local network using MQTT. No cloud dependency required.

.NOTES
    Author:  Markus Lassfolk
    Project: https://github.com/markus-lassfolk/PSYarbo
    License: MIT
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region — Auto-load Private functions (not exported)
$privateDir = Join-Path $PSScriptRoot 'Private'
if (Test-Path $privateDir) {
    Get-ChildItem -Path $privateDir -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}
#endregion

#region — Auto-load Public functions (exported via manifest)
$publicDir = Join-Path $PSScriptRoot 'Public'
if (Test-Path $publicDir) {
    Get-ChildItem -Path $publicDir -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}
#endregion

# Module is a work in progress — public functions will be added under Public/
Write-Verbose "PSYarbo module loaded. Version: $((Get-Module PSYarbo).Version)"
