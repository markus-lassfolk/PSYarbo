<#
.SYNOPSIS
    Record real MQTT traffic from your Yarbo robot and analyze coverage.

.DESCRIPTION
    Records live MQTT from the robot's broker (real data, not synthetic/fixture).
    Connects to the broker, subscribes to snowbot/#, and records all messages for
    the specified duration (default 60 seconds). Saves full payloads to a JSON file
    and runs Get-YarboMqttRecordingReport to show which topics were seen and which
    cmdlets expose that data. Run this on a machine on the same LAN as the robot;
    ensure build/Install-Dependencies.ps1 has been run so MQTTnet is available.

.PARAMETER Broker
    Broker IP or hostname. Optional if -DiscoverBroker is used.

.PARAMETER DiscoverBroker
    Discover the robot with Find-Yarbo and use its broker for recording (recommended).

.PARAMETER Port
    MQTT port. Default 1883.

.PARAMETER DurationSeconds
    How long to record. Default 60 (one minute).

.PARAMETER OutDir
    Directory for recording and report files. Default: current directory.

.PARAMETER SkipReport
    If set, only record; do not run the coverage report.

.EXAMPLE
    .\tools\Record-YarboMqtt.ps1 -DiscoverBroker
    Record 60s from the first robot found on the network (real MQTT).
.EXAMPLE
    .\tools\Record-YarboMqtt.ps1 -Broker 192.168.1.42 -DurationSeconds 60
    Record 60s from a known broker (real MQTT).
#>
[CmdletBinding(DefaultParameterSetName = 'Broker')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Broker')]
    [string]$Broker,
    [Parameter(Mandatory, ParameterSetName = 'Discover')]
    [switch]$DiscoverBroker,
    [int]$Port = 1883,
    [int]$DurationSeconds = 60,
    [string]$OutDir = '.',
    [switch]$SkipReport
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $scriptRoot 'src' 'PSYarbo') -Force -WarningAction SilentlyContinue

if ($PSCmdlet.ParameterSetName -eq 'Discover') {
    Write-Host "Discovering robot on the network..."
    $found = Find-Yarbo -TimeoutSeconds 15 -ErrorAction Stop
    if (-not $found -or $found.Count -eq 0) { throw "No Yarbo found. Ensure the robot is on and on the same LAN." }
    $Broker = $found[0].Broker
    Write-Host "Using broker: $Broker (SN: $($found[0].SerialNumber))"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$recordPath = Join-Path $OutDir "PSYarbo-MqttRecording-$stamp.json"
$reportPath = Join-Path $OutDir "PSYarbo-MqttReport-$stamp.txt"

Write-Host "Recording real MQTT for ${DurationSeconds}s from ${Broker}:${Port} -> $recordPath"
Invoke-YarboMqttSniff -Broker $Broker -Port $Port -DurationSeconds $DurationSeconds -RecordPath $recordPath

if (-not $SkipReport -and (Test-Path -LiteralPath $recordPath)) {
    Write-Host ""
    Get-YarboMqttRecordingReport -RecordingPath $recordPath -OutPath $reportPath
    Write-Host ""
    Write-Host "Report file: $reportPath"
}
