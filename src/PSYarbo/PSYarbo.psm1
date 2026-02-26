#Requires -Version 7.4
<#
.SYNOPSIS
    PSYarbo — PowerShell module for controlling Yarbo robot mowers via local MQTT and cloud REST API.

.DESCRIPTION
    Provides cmdlets to discover, connect to, and control Yarbo robot mowers
    on a local network using MQTT, and via cloud REST API for account management.

.NOTES
    Author:  Markus Lassfolk
    Project: https://github.com/markus-lassfolk/PSYarbo
    License: MIT
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region — Load MQTTnet via isolated AssemblyLoadContext
$libPath = Join-Path $PSScriptRoot 'lib'
$mqttDllPath = Join-Path $libPath 'MQTTnet.dll'

if (Test-Path $mqttDllPath) {
    $alcName = 'PSYarboMqttContext'
    $script:MqttALC = [System.Runtime.Loader.AssemblyLoadContext]::new($alcName, $true)
    $script:MqttAssembly = $script:MqttALC.LoadFromAssemblyPath((Resolve-Path $mqttDllPath).Path)
    Write-Verbose "PSYarbo: Loaded MQTTnet via isolated AssemblyLoadContext '$alcName'"
} else {
    $script:MqttAssembly = $null
    Write-Warning "MQTTnet.dll not found at '$mqttDllPath'. MQTT cmdlets will not work. Run build/Install-Dependencies.ps1 to download it."
}
#endregion

#region — Load classes (order matters)
$classFiles = @(
    'YarboExceptions'
    'YarboLightState'
    'YarboCommandResult'
    'YarboTelemetry'
    'YarboPlan'
    'YarboSchedule'
    'YarboRobot'
    'YarboConnection'
    'YarboCloudSession'
)
foreach ($class in $classFiles) {
    . (Join-Path $PSScriptRoot "Classes/$class.ps1")
}
#endregion

#region — Load private functions
Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -Recurse | ForEach-Object {
    . $_.FullName
}
#endregion

#region — Load public functions
Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -Recurse | ForEach-Object {
    . $_.FullName
}
#endregion

#region — Module-scoped state
$script:YarboConnections = [System.Collections.Generic.Dictionary[string, YarboConnection]]::new()
$script:YarboCloudSession = $null
$script:DefaultConnection = $null
#endregion

Write-Verbose "PSYarbo module loaded. Version: $((Get-Module PSYarbo).Version)"
