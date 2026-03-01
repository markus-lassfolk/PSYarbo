function Find-Yarbo {
    <#
.SYNOPSIS
    Auto-discovers Yarbo robots on the local network via MQTT heart_beat.

.DESCRIPTION
    Scans the specified subnet for MQTT brokers on port 1883.
    Uses parallel TCP port checks to quickly find candidate hosts, then
    performs a real MQTT connect + `snowbot/+/device/heart_beat` subscription
    for each candidate.  The serial number is extracted from the heart_beat
    topic (`snowbot/{SN}/device/heart_beat`).

    Only hosts that respond with a valid Yarbo heart_beat are returned.
    TCP-reachable brokers that do not publish a heart_beat within
    TimeoutSeconds are silently skipped.

.PARAMETER Subnet
    Network subnet(s) to scan in CIDR notation (e.g. 192.0.2.0/24). When not specified, scans all networks this machine has an IP on (LAN, Wi‑Fi, etc.). Prefix must be /16–/30.

.PARAMETER TimeoutSeconds
    How long to wait for each broker to produce a heart_beat. Default: 5.

.PARAMETER Port
    MQTT port to scan. Default: 1883.

.PARAMETER MaxHosts
    Maximum number of hosts to scan. Default: 512 (so a single /23 is fully scanned).

.PARAMETER ThrottleLimit
    Maximum number of concurrent TCP probe tasks. Default: 64.

.EXAMPLE
    Find-Yarbo
    Scans all local networks (auto-detected).

.EXAMPLE
    Find-Yarbo -Subnet 192.0.2.0/24 -TimeoutSeconds 10

.EXAMPLE
    Find-Yarbo -Subnet 192.0.2.0/22 -MaxHosts 1024

.LINK
    Connect-Yarbo
    about_PSYarbo_MQTT
#>
    [CmdletBinding()]
    [OutputType([YarboRobot])]
    param(
        [Parameter()]
        [AllowEmptyString()]
        [ValidateScript({
                if ([string]::IsNullOrEmpty($_)) { return $true }
                $_ -match '^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$'
            })]
        [string]$Subnet = '',

        [Parameter()]
        [ValidateRange(1, 120)]
        [int]$TimeoutSeconds = 5,

        [Parameter()]
        [int]$Port = 1883,

        [Parameter()]
        [ValidateRange(1, 65534)]
        [int]$MaxHosts = 512,

        [Parameter()]
        [ValidateRange(1, 256)]
        [int]$ThrottleLimit = 64
    )

    # ── 1. Resolve subnets to scan (local interfaces or -Subnet) ───────────────
    $userProvidedSubnet = -not [string]::IsNullOrWhiteSpace($Subnet)
    if ($userProvidedSubnet) {
        $subnetsToScan = @($Subnet.Trim())
    } else {
        $subnetsToScan = @(Get-PSYarboLocalSubnet)
        if ($subnetsToScan.Count -eq 0) {
            $subnetsToScan = @('192.168.1.0/24')
            Write-Verbose "[Find-Yarbo] No local subnets detected; using fallback $($subnetsToScan[0])"
        } else {
            Write-Verbose "[Find-Yarbo] Using local subnets: $($subnetsToScan -join ', ')"
        }
    }

    $ipList = @(Get-PSYarboSubnetIpList -Subnets $subnetsToScan -MaxHosts $MaxHosts -ValidateUserInput:$userProvidedSubnet)
    $hostCount = $ipList.Count
    Write-Verbose "[Find-Yarbo] Scanning $($subnetsToScan.Count) subnet(s), $hostCount hosts for MQTT brokers on port $Port"
    if ($hostCount -gt 512) {
        Write-Warning "Find-Yarbo: Scanning $hostCount hosts; this may be slow. Consider using a more specific -Subnet or reducing -MaxHosts to speed up the scan."
    }

    # ── 2. Parallel TCP probe — collect candidates ────────────────────────────
    $tcpTimeoutMs = [int]($TimeoutSeconds * 1000 * 0.4)  # 40% budget for TCP

    $tcpCandidates = @(
        $ipList | ForEach-Object -Parallel {
            $ip = $_
            $port = $using:Port
            $timeoutMs = $using:tcpTimeoutMs
            try {
                $c = [System.Net.Sockets.TcpClient]::new()
                try {
                    if ($c.ConnectAsync($ip, $port).Wait($timeoutMs) -and $c.Connected) {
                        $ip
                    }
                } finally {
                    $c.Dispose()
                }
            } catch {
                Write-Debug "[Find-Yarbo] TCP probe error for ${ip}: $($_.Exception.Message)"
            }
        } -ThrottleLimit $ThrottleLimit | Where-Object { $null -ne $_ }
    )
    $candidates = @($tcpCandidates)
    Write-Verbose "[Find-Yarbo] TCP probe found $($candidates.Count) candidate(s)"

    if ($candidates.Count -eq 0) {
        Write-Verbose "[Find-Yarbo] No MQTT brokers found."
        return
    }

    # ── 3. MQTT discovery — only brokers that publish Yarbo topics ─────────────
    # Use C# YarboMqttListener so the message-received handler runs in-process (reliable).
    if ($null -eq $script:MqttAssembly) {
        Write-Warning "[Find-Yarbo] MQTTnet assembly not loaded. Returning TCP-only results with unknown SerialNumber."
        foreach ($ip in $candidates) {
            $r = [YarboRobot]::new()
            $r.Broker = $ip
            $r.Port = $Port
            Write-Output $r
        }
        return
    }

    $listenerType = 'PSYarbo.Mqtt.YarboMqttListener' -as [type]
    if (-not $listenerType) {
        Write-Warning "[Find-Yarbo] YarboMqttListener not available. Returning TCP-only results."
        foreach ($ip in $candidates) {
            $r = [YarboRobot]::new()
            $r.Broker = $ip
            $r.Port = $Port
            Write-Output $r
        }
        return
    }

    $mqttTimeoutMs = [int](($TimeoutSeconds * 1000) * 0.6)  # 60% budget for MQTT
    # Only subscribe to Yarbo device topics (snowbot/{SN}/device/...) — filters out non-Yarbo brokers
    $yarboTopicFilters = @('snowbot/+/device/DeviceMSG', 'snowbot/+/device/data_feedback', 'snowbot/+/device/heart_beat')

    $discovered = @{}
    foreach ($ip in $candidates) {
        Write-Verbose "[Find-Yarbo] MQTT probe: connecting to ${ip}:${Port} (Yarbo topics only)"

        $listener = $null
        try {
            $listener = [PSYarbo.Mqtt.YarboMqttListener]::new()
            # Anonymous client ID for discovery (matches python-yarbo)
            $listener.Connect($ip, $Port, [string]::Empty, [TimeSpan]::FromSeconds(3))
            $listener.Subscribe([string[]]$yarboTopicFilters)

            $first = $listener.WaitForFirstMessage($mqttTimeoutMs)
            if ($null -ne $first -and $first.Topic.Length -gt 0) {
                # Topic: snowbot/{SN}/device/...
                $parts = $first.Topic -split '/'
                $sn = if ($parts.Count -ge 2 -and $parts[1] -ne '+') { $parts[1] } else { $null }
                if ($sn) {
                    if (-not $discovered.ContainsKey($sn)) {
                        $discovered[$sn] = [System.Collections.Generic.List[hashtable]]::new()
                    }
                    Write-Verbose "[Find-Yarbo] Discovered Yarbo SN=$sn at ${ip}:${Port} (topic: $($first.Topic))"
                    $discovered[$sn].Add(@{ IP = $ip; Port = $Port; SerialNumber = $sn })
                } else {
                    Write-Verbose "[Find-Yarbo] ${ip}:${Port} — received topic without SN (skipped)"
                }
            } else {
                Write-Verbose "[Find-Yarbo] ${ip}:${Port} — no Yarbo message within ${TimeoutSeconds}s (skipped)"
            }
        } catch {
            Write-Verbose "[Find-Yarbo] ${ip}:${Port} — MQTT connect failed: $($_.Exception.Message)"
        } finally {
            if ($listener) {
                try { $listener.Dispose() } catch { Write-Debug "[Find-Yarbo] Listener dispose: $($_.Exception.Message)" }
            }
        }
    }
    foreach ($endpoints in $discovered.Values) {
        $ep = $endpoints[0]
        $r = [YarboRobot]::new()
        $r.Broker = $ep.IP
        $r.Port = $ep.Port
        $r.SerialNumber = $ep.SerialNumber
        $r.LastUpdated = [datetime]::UtcNow
        Write-Output $r
    }
}
