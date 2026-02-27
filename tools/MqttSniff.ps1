<#
.SYNOPSIS
    Sniff all MQTT messages from a broker for troubleshooting (topic + payload size).
.DESCRIPTION
    Connects to the given broker, subscribes to # (all topics), and logs every
    message received for the specified duration. Use to verify that the broker
    sends Yarbo traffic and to see actual topic names (snowbot/ vs yarbo/ etc.).
.PARAMETER Broker
    Broker IP or hostname (use Find-YarboDevice or Find-Yarbo to discover).
.PARAMETER Port
    MQTT port. Default 1883.
.PARAMETER DurationSeconds
    How long to capture. Default 15.
.EXAMPLE
    .\tools\MqttSniff.ps1 -Broker <rover-ip> -DurationSeconds 20
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Broker,
    [int]$Port = 1883,
    [int]$DurationSeconds = 15
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $scriptRoot 'src' 'PSYarbo') -Force -WarningAction SilentlyContinue

$logFile = Join-Path ([System.IO.Path]::GetTempPath()) "PSYarbo-MqttSniff-$(Get-Date -Format 'yyyyMMddHHmmss').log"
Write-Host "LogPath: $logFile"

Write-Host "=== PowerShell adapter sniffer (adapter debug log shows if handler is invoked) ==="
Invoke-YarboMqttSniff -Broker $Broker -Port $Port -DurationSeconds $DurationSeconds -SelfTest -LogPath $logFile
$fi = Get-Item $logFile -ErrorAction SilentlyContinue; Write-Host "Log file size: $(if ($fi) { $fi.Length } else { 0 }) bytes"
