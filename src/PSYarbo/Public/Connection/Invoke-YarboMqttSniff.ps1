<#
.SYNOPSIS
    Listen to MQTT messages from a broker (Yarbo topics by default).

.DESCRIPTION
    Connects to the given broker and listens for MQTT messages. By default
    subscribes only to snowbot/# so you only see Yarbo robot traffic; use
    -AllTopics to subscribe to # (all topics) for troubleshooting.

.PARAMETER Broker
    Broker IP or hostname.

.PARAMETER Port
    MQTT port. Default 1883.

.PARAMETER DurationSeconds
    How long to listen. Default 15.

.PARAMETER AllTopics
    If set, subscribe to # (all topics). Default is snowbot/# (Yarbo only).

.PARAMETER SelfTest
    If set, publish a test message to PSYarbo/selftest and confirm it is received.

.PARAMETER LogPath
    If set, append every received message line to this file.

.OUTPUTS
    PSCustomObject[] with Topic, PayloadBytes, At (timestamp).
#>
function Invoke-YarboMqttSniff {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Broker,
        [int]$Port = 1883,
        [int]$DurationSeconds = 15,
        [switch]$AllTopics,
        [switch]$SelfTest,
        [string]$LogPath
    )

    if (-not $script:MqttAssembly) {
        throw "MQTTnet not loaded. Run build/Install-Dependencies.ps1 first."
    }

    $listenerType = 'PSYarbo.Mqtt.YarboMqttListener' -as [type]
    if (-not $listenerType) {
        throw "YarboMqttListener not available. Ensure PSYarbo module loaded correctly."
    }

    # Only subscribe to Yarbo topics so we only see Yarbo MQTT packages (unless -AllTopics)
    $topicFilters = if ($AllTopics) { @('#') } else { @('snowbot/#') }
    if ($SelfTest -and -not $AllTopics) {
        $topicFilters += 'PSYarbo/selftest'
    }
    $filterDesc = if ($AllTopics) { 'all topics (#)' } else { 'Yarbo only (snowbot/#)' }

    $listener = $null
    try {
        $listener = [PSYarbo.Mqtt.YarboMqttListener]::new()
        $clientId = "PSYarbo-Sniff-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
        Write-Host "Connecting to ${Broker}:${Port} (filter: $filterDesc) ..."
        $listener.Connect($Broker, $Port, $clientId, [TimeSpan]::FromSeconds(5))
        $listener.Subscribe([string[]]$topicFilters)
        Write-Host "Listening for ${DurationSeconds}s ..."

        if ($SelfTest) {
            Write-Host "Self-test: publishing to PSYarbo/selftest ..."
            $listener.Publish('PSYarbo/selftest', [System.Text.Encoding]::UTF8.GetBytes('hello'))
            Start-Sleep -Seconds 2
        }

        Start-Sleep -Seconds $DurationSeconds

        $received = $listener.GetReceivedMessages()
        $all = @(
            foreach ($msg in $received) {
                $len = if ($msg.Payload) { $msg.Payload.Length } else { 0 }
                $at = [datetime]::UtcNow
                Write-Host "[MQTT] $($msg.Topic) ($len bytes)"
                if ($LogPath) {
                    try {
                        [System.IO.File]::AppendAllText($LogPath, "[$(Get-Date -Format 'o')] $($msg.Topic) ($len bytes)`n")
                    } catch { $null = $_ }
                }
                [PSCustomObject]@{ Topic = $msg.Topic; PayloadBytes = $len; At = $at }
            }
        )

        if ($SelfTest) {
            $selftestCount = @($all | Where-Object { $_.Topic -eq 'PSYarbo/selftest' }).Count
            Write-Host "Self-test: received $selftestCount message(s) on PSYarbo/selftest (expected 1)."
        }

        Write-Host ""
        Write-Host "=== Sniff summary: $($all.Count) messages ==="
        if ($all.Count -gt 0) {
            $all | Group-Object -Property Topic | Sort-Object Count -Descending | ForEach-Object {
                $sample = $_.Group[0]
                Write-Host "  $($_.Count)x $($_.Name) ($($sample.PayloadBytes) bytes sample)"
            }
        } else {
            Write-Host "  No messages received. Ensure the broker is a Yarbo MQTT broker and the robot is publishing."
        }
        return $all
    } finally {
        if ($listener) {
            try { $listener.Dispose() } catch { $null = $_ }
        }
    }
}
