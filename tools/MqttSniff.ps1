<#
.SYNOPSIS
    Sniff MQTT messages from a broker (topic + size; optional full recording).
.DESCRIPTION
    Connects to the broker, subscribes to snowbot/# (Yarbo traffic), and logs
    each message. Use -RecordPath to save full payloads for Get-YarboMqttRecordingReport.
.PARAMETER Broker
    Broker IP or hostname (use Find-YarboDevice or Find-Yarbo to discover).
.PARAMETER Port
    MQTT port. Default 1883.
.PARAMETER DurationSeconds
    How long to capture. Default 15. Use 60 for a one-minute recording.
.PARAMETER RecordPath
    If set, save a JSON recording of all messages for coverage report.
.EXAMPLE
    .\tools\MqttSniff.ps1 -Broker <rover-ip> -DurationSeconds 60 -RecordPath ./recording.json
    Get-YarboMqttRecordingReport -RecordingPath ./recording.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Broker,
    [int]$Port = 1883,
    [int]$DurationSeconds = 15,
    [string]$RecordPath
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $scriptRoot 'src' 'PSYarbo') -Force -WarningAction SilentlyContinue

$logFile = Join-Path ([System.IO.Path]::GetTempPath()) "PSYarbo-MqttSniff-$(Get-Date -Format 'yyyyMMddHHmmss').log"
Write-Host "LogPath: $logFile"

$params = @{ Broker = $Broker; Port = $Port; DurationSeconds = $DurationSeconds; SelfTest = $true; LogPath = $logFile }
if ($RecordPath) { $params['RecordPath'] = $RecordPath }
Invoke-YarboMqttSniff @params
$fi = Get-Item $logFile -ErrorAction SilentlyContinue; Write-Host "Log file size: $(if ($fi) { $fi.Length } else { 0 }) bytes"
