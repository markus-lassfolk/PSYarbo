<#
.SYNOPSIS
    Exports a redacted MQTT/connection bundle for support (e.g. GlitchTip or maintainers).

.DESCRIPTION
    Produces a JSON file containing MQTT and connection metadata plus redacted message summaries.
    Use this when reporting issues or when asked to provide a "full MQTT dump" for troubleshooting
    firmware versions, heads/attachments, or unsupported configurations.
    Sensitive data (tokens, credentials) is redacted. You can upload the output file to your
    issue tracker or GlitchTip.

.PARAMETER Path
    Output file path for the support bundle (JSON). Created if the directory does not exist.

.PARAMETER RecordingPath
    Optional. Path to a recording from Invoke-YarboMqttSniff -RecordPath. If provided, the bundle
    includes topic list, message counts, and decoded payload keys (values redacted) from that recording.

.PARAMETER Connection
    Optional. A YarboConnection. If provided, the bundle includes the last N entries from
    CommandLog and TelemetryLog (no raw payloads are stored there; safe to export).

.PARAMETER CommandLogEntries
    When -Connection is used, how many recent CommandLog entries to include. Default 100.

.PARAMETER TelemetryLogEntries
    When -Connection is used, how many recent TelemetryLog entries to include. Default 50.

.EXAMPLE
    Export-YarboSupportBundle -Path ./support-bundle.json -RecordingPath ./mqtt-recording.json

.EXAMPLE
    $conn = Connect-Yarbo -Broker 192.0.2.1 -SerialNumber YB123
    Get-YarboStatus -Connection $conn
    Export-YarboSupportBundle -Path ./support-bundle.json -Connection $conn

.LINK
    Invoke-YarboMqttSniff
    Get-YarboMqttRecordingReport
    https://github.com/markus-lassfolk/python-yarbo/issues/59
#>
function Export-YarboSupportBundle {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string]$RecordingPath,

        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$CommandLogEntries = 100,

        [Parameter()]
        [ValidateRange(1, 500)]
        [int]$TelemetryLogEntries = 50
    )

    $bundle = [ordered]@{
        ExportDate    = [datetime]::UtcNow.ToString('o')
        Module        = 'PSYarbo'
        ModuleVersion = $script:ModuleVersion
        Source        = [System.Collections.Generic.List[string]]::new()
        Recording     = $null
        ConnectionLog = $null
    }

    if ($RecordingPath) {
        if (-not (Test-Path -LiteralPath $RecordingPath)) {
            $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                    [System.IO.FileNotFoundException]::new("Recording not found.", $RecordingPath),
                    'PSYarbo.RecordingNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $RecordingPath
                ))
        } else {
            $bundle.Source.Add('Recording')
            $raw = Get-Content -LiteralPath $RecordingPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $messages = @($raw.Messages)
            $byTopic = @{}
            $decodedSamples = @{}
            foreach ($m in $messages) {
                $t = $m.Topic
                if (-not $byTopic[$t]) { $byTopic[$t] = 0 }
                $byTopic[$t]++
                if (-not $decodedSamples[$t] -and $m.PayloadBase64) {
                    try {
                        $bytes = [Convert]::FromBase64String($m.PayloadBase64)
                        $decoded = ConvertFrom-ZlibPayload -Data $bytes
                        if ($decoded -is [PSCustomObject]) {
                            $keys = ($decoded.PSObject.Properties | ForEach-Object { $_.Name }) -join ', '
                            $decodedSamples[$t] = Protect-YarboLogMessage $keys
                        }
                    } catch { $decodedSamples[$t] = '(decode failed)' }
                }
            }
            $bundle.Recording = [ordered]@{
                RecordedAt       = $raw.RecordedAt
                Broker           = $raw.Broker
                Port             = $raw.Port
                DurationSeconds  = $raw.DurationSeconds
                MessageCount     = $messages.Count
                Topics           = [ordered]@{}
                DecodedKeysSample = [ordered]@{}
            }
            foreach ($t in ($byTopic.Keys | Sort-Object)) { $bundle.Recording.Topics[$t] = $byTopic[$t] }
            foreach ($t in ($decodedSamples.Keys | Sort-Object)) { $bundle.Recording.DecodedKeysSample[$t] = $decodedSamples[$t] }
        }
    }

    if ($Connection) {
        $bundle.Source.Add('Connection')
        $cmdArr = $Connection.CommandLog.ToArray() | Select-Object -Last $CommandLogEntries
        $telArr = $Connection.TelemetryLog.ToArray() | Select-Object -Last $TelemetryLogEntries
        $bundle.ConnectionLog = [ordered]@{
            Broker        = $Connection.Broker
            Port          = $Connection.Port
            SerialNumber  = $Connection.SerialNumber
            CommandLog    = @($cmdArr | ForEach-Object {
                    $entry = [ordered]@{
                        Timestamp = $_.Timestamp.ToString('o')
                        Command   = $_.Command
                        Direction = $_.Direction
                        Topic     = $_.Topic
                    }
                    if ($_.PSObject.Properties['State']) { $entry['State'] = $_.State }
                    if ($_.PSObject.Properties['Message']) { $entry['Message'] = if ($_.Message) { Protect-YarboLogMessage $_.Message } else { $null } }
                    $entry
                })
            TelemetryLog = @($telArr | ForEach-Object {
                    [ordered]@{
                        At     = $_.At.ToString('o')
                        Topic  = $_.Topic
                        Source = $_.Source
                    }
                })
        }
    }

    if ($bundle.Source.Count -eq 0) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new('Specify at least one of -RecordingPath or -Connection.'),
                'PSYarbo.SupportBundleNoSource',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $null
            ))
    }

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $bundle | ConvertTo-Json -Depth 10 -Compress:$false | Set-Content -LiteralPath $Path -Encoding UTF8
    Write-Verbose "Support bundle written to $Path (sources: $($bundle.Source -join ', ')). You can upload this to GlitchTip or attach to an issue."
    Get-Item -LiteralPath $Path
}
