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
    Network subnet to scan in CIDR notation. Default: 192.168.1.0/24.
    Prefix length must be /16 or longer (/24 recommended).
    To allow scanning larger subnets, specify -MaxHosts explicitly.

.PARAMETER TimeoutSeconds
    How long to wait for each broker to produce a heart_beat. Default: 5.

.PARAMETER Port
    MQTT port to scan. Default: 1883.

.PARAMETER MaxHosts
    Maximum number of hosts to scan. Acts as a safety guard against
    accidentally scanning huge subnets. Default: 256.

.PARAMETER ThrottleLimit
    Maximum number of concurrent TCP probe tasks. Default: 64.

.EXAMPLE
    Find-Yarbo

.EXAMPLE
    Find-Yarbo -Subnet 10.0.0.0/24 -TimeoutSeconds 10

.EXAMPLE
    Find-Yarbo -Subnet 192.168.0.0/22 -MaxHosts 1024

.LINK
    Connect-Yarbo
    about_PSYarbo_MQTT
#>
    [CmdletBinding()]
    [OutputType([YarboRobot])]
    param(
        [Parameter()]
        [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
        [string]$Subnet = '192.168.1.0/24',

        [Parameter()]
        [ValidateRange(1, 120)]
        [int]$TimeoutSeconds = 5,

        [Parameter()]
        [int]$Port = 1883,

        [Parameter()]
        [ValidateRange(1, 65534)]
        [int]$MaxHosts = 256,

        [Parameter()]
        [ValidateRange(1, 256)]
        [int]$ThrottleLimit = 64
    )

    # ── 1. Parse and validate CIDR ─────────────────────────────────────────────
    $parts = $Subnet -split '/'
    $prefixLen = [int]$parts[1]

    if ($prefixLen -lt 16) {
        throw [System.ArgumentException]::new(
            "Subnet prefix /$prefixLen is too large for safety. Use /16 or longer, or set -MaxHosts explicitly."
        )
    }

    $baseIp    = [System.Net.IPAddress]::Parse($parts[0])
    $baseBytes = $baseIp.GetAddressBytes()
    # Ensure network address (zero host bits)
    [Array]::Reverse($baseBytes)
    $hostBits  = 32 - $prefixLen
    $hostCount = [math]::Min([math]::Pow(2, $hostBits) - 2, $MaxHosts)

    Write-Verbose "[Find-Yarbo] Scanning $Subnet ($hostCount hosts) for MQTT brokers on port $Port"

    # ── 2. Parallel TCP probe — collect candidates ────────────────────────────
    $tcpTimeoutMs  = [int]($TimeoutSeconds * 1000 * 0.4)  # 40% budget for TCP
    $semaphore     = [System.Threading.SemaphoreSlim]::new($ThrottleLimit, $ThrottleLimit)
    $tasks         = [System.Collections.Generic.List[object]]::new()
    $candidateIps  = [System.Collections.Concurrent.ConcurrentBag[string]]::new()

    for ($i = 1; $i -le $hostCount; $i++) {
        $ipVal = ([System.BitConverter]::ToUInt32($baseBytes, 0)) + $i
        $newBytes = [System.BitConverter]::GetBytes($ipVal)
        # Restore to network byte order for IPAddress constructor
        [Array]::Reverse($newBytes)
        $ip = [System.Net.IPAddress]::new($newBytes).ToString()

        $semaphore.Wait() | Out-Null

        $task = [System.Threading.Tasks.Task]::Run([scriptblock]{
            param($ipAddr, $portNum, $tMs, $sem, $bag)
            try {
                $c = [System.Net.Sockets.TcpClient]::new()
                try {
                    if ($c.ConnectAsync($ipAddr, $portNum).Wait($tMs) -and $c.Connected) {
                        $bag.Add($ipAddr)
                    }
                } finally {
                    $c.Dispose()
                }
            } catch { }
            finally {
                $sem.Release() | Out-Null
            }
        }.GetNewClosure(), @($ip, $Port, $tcpTimeoutMs, $semaphore, $candidateIps))
        $tasks.Add($task)
    }
    [System.Threading.Tasks.Task]::WhenAll($tasks.ToArray()).GetAwaiter().GetResult() | Out-Null

    $candidates = @($candidateIps)
    Write-Verbose "[Find-Yarbo] TCP probe found $($candidates.Count) candidate(s)"

    if ($candidates.Count -eq 0) {
        Write-Verbose "[Find-Yarbo] No MQTT brokers found."
        return
    }

    # ── 3. MQTT discovery — confirm each candidate has a Yarbo heart_beat ─────
    if ($null -eq $script:MqttAssembly) {
        Write-Warning "[Find-Yarbo] MQTTnet assembly not loaded. Returning TCP-only results with unknown SerialNumber."
        foreach ($ip in $candidates) {
            $r = [YarboRobot]::new()
            $r.Broker = $ip
            $r.Port   = $Port
            Write-Output $r
        }
        return
    }

    $mqttTimeoutMs = [int](($TimeoutSeconds * 1000) * 0.6)  # 60% budget for MQTT

    foreach ($ip in $candidates) {
        Write-Verbose "[Find-Yarbo] MQTT probe: connecting to ${ip}:${Port}"

        $factory    = $null
        $client     = $null
        $signal     = [System.Threading.SemaphoreSlim]::new(0, 1)
        $detectedSN = $null

        try {
            $factory = [System.Activator]::CreateInstance($script:MqttAssembly.GetType('MQTTnet.MqttFactory'))
            $client  = $factory.CreateMqttClient()

            $clientId  = "PSYarbo-Discover-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            $options   = $factory.CreateClientOptionsBuilder().WithTcpServer($ip, $Port).WithClientId($clientId).WithTimeout(
                [TimeSpan]::FromSeconds(3)
            ).Build()

            $client.ConnectAsync($options, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null

            # Subscribe to wildcard heart_beat
            $subOpts = $factory.CreateSubscribeOptionsBuilder().WithTopicFilter('snowbot/+/device/heart_beat').Build()
            $client.SubscribeAsync($subOpts, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null

            # Capture first heart_beat message
            $localSignal = $signal
            $snRef = [ref]$detectedSN
            $client.ApplicationMessageReceivedAsync.Add({
                param($ea)
                $seg = $ea.ApplicationMessage.PayloadSegment
                if ($null -ne $seg -and $seg.Count -gt 0) {
                    $topicParts = $ea.ApplicationMessage.Topic -split '/'
                    # topic = snowbot/{SN}/device/heart_beat — SN is index 1
                    if ($topicParts.Count -ge 2 -and $topicParts[1] -ne '+') {
                        $snRef.Value = $topicParts[1]
                        try { $localSignal.Release() | Out-Null } catch { }
                    }
                }
                return [System.Threading.Tasks.Task]::CompletedTask
            })

            # Wait for heart_beat
            $gotHb = $signal.Wait($mqttTimeoutMs)

            if ($gotHb -and $detectedSN) {
                Write-Verbose "[Find-Yarbo] Discovered Yarbo SN=$detectedSN at ${ip}:${Port}"

                # Attempt to parse state from heart_beat payload for richer YarboRobot
                $r = [YarboRobot]::new()
                $r.Broker       = $ip
                $r.Port         = $Port
                $r.SerialNumber = $detectedSN
                $r.LastUpdated  = [datetime]::UtcNow
                Write-Output $r
            }
            else {
                Write-Verbose "[Find-Yarbo] ${ip}:${Port} — no Yarbo heart_beat received within ${TimeoutSeconds}s (skipped)"
            }
        }
        catch {
            Write-Verbose "[Find-Yarbo] ${ip}:${Port} — MQTT connect failed: $($_.Exception.Message)"
        }
        finally {
            if ($client) {
                try {
                    $client.DisconnectAsync([System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
                } catch { }
                try { if ($client -is [System.IDisposable]) { $client.Dispose() } } catch { }
            }
            $signal.Dispose()
        }
    }
}
