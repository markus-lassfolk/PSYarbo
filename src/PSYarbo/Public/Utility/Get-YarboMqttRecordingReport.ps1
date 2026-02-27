<#
.SYNOPSIS
    Analyzes an MQTT recording file and reports which topics are exposed by which cmdlets.

.DESCRIPTION
    Reads a JSON recording produced by Invoke-YarboMqttSniff -RecordPath (or Record-YarboMqtt.ps1).
    For meaningful coverage, use a recording of real MQTT from your robot, not synthetic/fixture data.
    Decodes zlib payloads where possible, groups by topic pattern, and outputs a coverage report:
    which MQTT topics were seen and which PSYarbo cmdlets expose that data.

.PARAMETER RecordingPath
    Path to the JSON recording file (from Invoke-YarboMqttSniff -RecordPath).

.PARAMETER OutPath
    If set, write the report to this file as well as the console.

.EXAMPLE
    Invoke-YarboMqttSniff -Broker 192.0.2.1 -DurationSeconds 60 -RecordPath ./mqtt-recording.json
    Get-YarboMqttRecordingReport -RecordingPath ./mqtt-recording.json
#>
function Get-YarboMqttRecordingReport {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Path')]
        [string]$RecordingPath,

        [string]$OutPath
    )

    if (-not (Test-Path -LiteralPath $RecordingPath)) {
        $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                [System.IO.FileNotFoundException]::new("Recording not found.", $RecordingPath),
                'PSYarbo.RecordingNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $RecordingPath
            ))
        return
    }

    $raw = Get-Content -LiteralPath $RecordingPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $messages = @($raw.Messages)
    if ($messages.Count -eq 0) {
        Write-Host "Recording has 0 messages. Nothing to report."
        return
    }

    # Topic suffix (e.g. device/DeviceMSG) -> cmdlets that expose this data
    $topicToCmdlets = @{
        'device/DeviceMSG'         = @('Get-YarboStatus', 'Get-YarboRobot', 'Get-YarboTelemetry', 'Watch-YarboTelemetry')
        'device/heart_beat'        = @('Watch-YarboTelemetry -IncludeHeartbeat', 'Connection.LastHeartbeat / LastWorkingState')
        'device/data_feedback'     = @('(command responses) Get-YarboPlan', 'Get-YarboStatus', 'Get-YarboGlobalParams', 'Get-YarboSchedule', 'etc.')
        'device/plan_feedback'     = @('Watch-YarboTelemetry -IncludePlanFeedback', 'Connection.LastPlanFeedback')
        'device/recharge_feedback' = @('Watch-YarboTelemetry', 'Connection.LastRechargeFeedback')
    }

    $bySuffix = @{}
    $decodedSamples = @{}
    foreach ($m in $messages) {
        $topic = $m.Topic
        $suffix = $null
        if ($topic -match 'snowbot/[^/]+/(.+)$') { $suffix = $Matches[1] }
        elseif ($topic -match '^(.+)$') { $suffix = $topic }
        if (-not $suffix) { continue }
        if (-not $bySuffix[$suffix]) { $bySuffix[$suffix] = 0; $decodedSamples[$suffix] = $null }
        $bySuffix[$suffix]++

        if (-not $decodedSamples[$suffix] -and $m.PayloadBase64) {
            try {
                $bytes = [Convert]::FromBase64String($m.PayloadBase64)
                $decoded = ConvertFrom-ZlibPayload -Data $bytes
                if ($decoded) { $decodedSamples[$suffix] = $decoded }
            } catch { $null = $_ }
        }
    }

    $reportLines = [System.Collections.Generic.List[string]]::new()
    $reportLines.Add("=== MQTT recording report: $RecordingPath ===")
    $reportLines.Add("Recorded: $($raw.RecordedAt) | Broker: $($raw.Broker):$($raw.Port) | Duration: $($raw.DurationSeconds)s | Messages: $($raw.MessageCount)")
    $reportLines.Add("")
    $reportLines.Add("--- Topics seen (suffix) | Count | Exposed by cmdlets ---")

    $covered = [System.Collections.Generic.List[string]]::new()
    $gaps = [System.Collections.Generic.List[string]]::new()
    foreach ($suffix in ($bySuffix.Keys | Sort-Object)) {
        $count = $bySuffix[$suffix]
        $cmdlets = $topicToCmdlets[$suffix]
        if ($cmdlets) {
            $covered.Add($suffix)
            $reportLines.Add("  $suffix | $count | $($cmdlets -join ', ')")
        } else {
            $gaps.Add($suffix)
            $reportLines.Add("  $suffix | $count | (no cmdlet mapping - consider adding support)")
        }
    }

    $reportLines.Add("")
    $reportLines.Add("--- Decoded payload sample keys (first message per topic) ---")
    foreach ($suffix in ($decodedSamples.Keys | Sort-Object)) {
        $sample = $decodedSamples[$suffix]
        if ($sample -is [PSCustomObject]) {
            $keys = ($sample.PSObject.Properties | ForEach-Object { $_.Name }) -join ', '
            $reportLines.Add("  $suffix : $keys")
        } else {
            $reportLines.Add("  $suffix : (decode failed or empty)")
        }
    }

    $reportLines.Add("")
    $reportLines.Add("--- Summary ---")
    $reportLines.Add("  Topics with cmdlet coverage: $($covered.Count)")
    if ($gaps.Count -gt 0) {
        $reportLines.Add("  Topics not yet mapped to cmdlets: $($gaps -join ', ')")
    } else {
        $reportLines.Add("  All observed topics have cmdlet coverage.")
    }

    $text = $reportLines -join [Environment]::NewLine
    Write-Host $text

    if ($OutPath) {
        $dir = Split-Path -Parent $OutPath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $text | Set-Content -LiteralPath $OutPath -Encoding UTF8
        Write-Verbose "Report written to $OutPath"
    }

    [PSCustomObject]@{
        RecordingPath   = $RecordingPath
        MessageCount    = $raw.MessageCount
        TopicsSeen      = @($bySuffix.Keys)
        TopicsCovered   = @($covered)
        TopicsNotMapped = @($gaps)
        ReportText      = $text
    }
}
