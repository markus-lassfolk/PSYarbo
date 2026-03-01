function Find-YarboDevice {
    <#
.SYNOPSIS
    Discovers Yarbo MQTT endpoints and labels them as Rover vs DC with a recommendation.

.DESCRIPTION
    Scans the local network for Yarbo MQTT brokers (port 1883), verifies each via
    snowbot/+/device/ heartbeat topics, then resolves MAC addresses and classifies
    each endpoint as Rover or DC using the MAC address:
    - Rover = direct WiFi to the mower (MAC is not locally administered).
    - DC = base station / data center bridge (MAC is locally administered).
    When the MAC cannot be resolved, the endpoint is listed as Rover and MAC shows
    "(unknown)"; classification is then uncertain. If both IPs show the same MAC
    (e.g. traffic via the DC port-forward) or no locally-administered MAC is seen,
    we cannot tell Rover from DC — use both addresses in failover order instead.

    Output order is try-order: recommended first, then others. Use the first address
    as primary (e.g. in Home Assistant); if it is unreachable, try the next (like
    primary/secondary DNS).

    Optionally tries DNS hostname "YARBO" as a fast-path for the DC before scanning.

.PARAMETER Subnet
    Network subnet(s) to scan in CIDR notation. When not specified, scans all networks this machine has an IP on (LAN, Wi‑Fi, etc.).

.PARAMETER TimeoutSeconds
    How long to wait per broker for a Yarbo message. Default: 5.

.PARAMETER Port
    MQTT port. Default: 1883.

.PARAMETER MaxHosts
    Maximum hosts to scan. Default: 512 (so a /23 is fully scanned).

.PARAMETER ThrottleLimit
    Concurrent TCP probe tasks. Default: 64.

.EXAMPLE
    Find-YarboDevice

.EXAMPLE
    Find-YarboDevice -Subnet 192.0.2.0/24 -TimeoutSeconds 10

.EXAMPLE
    # Primary/secondary for failover (e.g. Home Assistant): try first, then second if unreachable.
    $endpoints = Find-YarboDevice
    $primary = $endpoints[0].IPAddress; $secondary = $endpoints[1].IPAddress

.OUTPUTS
    YarboEndpoint[] with IPAddress, Port, Path (Rover|DC), MacAddress, Recommended, Hostname, SerialNumber, Status.

.LINK
    Find-Yarbo
    Connect-Yarbo
    https://github.com/markus-lassfolk/PSYarbo/issues/30
#>
    [CmdletBinding()]
    [OutputType([YarboEndpoint])]
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

    $InformationPreference = 'Continue'

    # ── DNS fast-path: try hostname YARBO (DC may register via DHCP) ─────────
    $dnsFirst = [System.Collections.Generic.List[string]]::new()
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses('YARBO')
        foreach ($a in $resolved) {
            if ($a.AddressFamily -eq 'InterNetwork') {
                $dnsFirst.Add($a.ToString())
            }
        }
    } catch {
        Write-Debug "[Find-YarboDevice] DNS YARBO lookup: $($_.Exception.Message)"
    }

    # ── Resolve subnets to scan (local interfaces or -Subnet) ────────────────
    $userProvidedSubnet = -not [string]::IsNullOrWhiteSpace($Subnet)
    if ($userProvidedSubnet) {
        $subnetsToScan = @($Subnet.Trim())
    } else {
        $subnetsToScan = @(Get-PSYarboLocalSubnet)
        if ($subnetsToScan.Count -eq 0) {
            $subnetsToScan = @('192.168.1.0/24')
            Write-Verbose "[Find-YarboDevice] No local subnets detected; using fallback $($subnetsToScan[0])"
        } else {
            Write-Verbose "[Find-YarboDevice] Using local subnets: $($subnetsToScan -join ', ')"
        }
    }

    $ipList = @(Get-PSYarboSubnetIpList -Subnets $subnetsToScan -MaxHosts $MaxHosts -ValidateUserInput:$userProvidedSubnet)
    $hostCount = $ipList.Count
    Write-Verbose "[Find-YarboDevice] Scanning $($subnetsToScan.Count) subnet(s), $hostCount hosts"
    if ($hostCount -gt 512) {
        Write-Warning "Find-YarboDevice: Scanning $hostCount hosts; this may be slow. Consider using a more specific -Subnet or reducing -MaxHosts to speed up the scan."
    }

    # ── TCP probe ────────────────────────────────────────────────────────────
    $tcpTimeoutMs = [int]($TimeoutSeconds * 1000 * 0.4)
    $tcpCandidates = @(
        $ipList | ForEach-Object -Parallel {
            $ip = $_
            $port = $using:Port
            $timeoutMs = $using:tcpTimeoutMs
            try {
                $c = [System.Net.Sockets.TcpClient]::new()
                try {
                    if ($c.ConnectAsync($ip, $port).Wait($timeoutMs) -and $c.Connected) { $ip }
                } finally { $c.Dispose() }
            } catch { Write-Debug "[Find-YarboDevice] TCP $ip : $($_.Exception.Message)" }
        } -ThrottleLimit $ThrottleLimit | Where-Object { $null -ne $_ }
    )
    $candidates = @($dnsFirst) + @($tcpCandidates) | Select-Object -Unique
    Write-Verbose "[Find-YarboDevice] Candidates: $($candidates.Count)"

    if ($candidates.Count -eq 0) {
        Write-Verbose "[Find-YarboDevice] No MQTT brokers found."
        return
    }

    # ── MQTT verify and collect (IP, SerialNumber, Hostname) ───────────────────
    $verified = [System.Collections.Generic.List[hashtable]]::new()
    $yarboTopicFilters = @('snowbot/+/device/DeviceMSG', 'snowbot/+/device/data_feedback', 'snowbot/+/device/heart_beat')
    $mqttTimeoutMs = [int](($TimeoutSeconds * 1000) * 0.6)

    $listenerType = 'PSYarbo.Mqtt.YarboMqttListener' -as [type]
    if ($null -eq $script:MqttAssembly -or -not $listenerType) {
        Write-Warning "[Find-YarboDevice] MQTTnet/YarboMqttListener not available. Cannot verify Yarbo brokers."
        return
    }

    foreach ($ip in $candidates) {
        $hostname = if ($dnsFirst -contains $ip) { 'YARBO' } else { $null }
        $listener = $null
        try {
            $listener = [PSYarbo.Mqtt.YarboMqttListener]::new()
            $listener.Connect($ip, $Port, [string]::Empty, [TimeSpan]::FromSeconds(3))
            $listener.Subscribe([string[]]$yarboTopicFilters)
            $first = $listener.WaitForFirstMessage($mqttTimeoutMs)
            if ($null -ne $first -and $first.Topic.Length -gt 0) {
                $topicParts = $first.Topic -split '/'
                $sn = if ($topicParts.Count -ge 2 -and $topicParts[1] -ne '+') { $topicParts[1] } else { $null }
                if ($sn) {
                    $verified.Add(@{ IP = $ip; Port = $Port; SerialNumber = $sn; Hostname = $hostname })
                    Write-Verbose "[Find-YarboDevice] Verified Yarbo at ${ip}:${Port} SN=$sn"
                }
            }
        } catch {
            Write-Verbose "[Find-YarboDevice] ${ip}:${Port} — $($_.Exception.Message)"
        } finally {
            if ($listener) {
                try { $listener.Dispose() } catch {
                    Write-Debug "[Find-YarboDevice] Listener dispose: $($_.Exception.Message)"
                }
            }
        }
    }

    if ($verified.Count -eq 0) {
        Write-Verbose "[Find-YarboDevice] No Yarbo brokers responded with device topics."
        return
    }

    # ── Enrich with MAC, Path (Rover/DC), Recommended ────────────────────────
    # Prime ARP so we can resolve MAC (Rover vs DC is determined by locally-administered MAC).
    foreach ($v in $verified) {
        Invoke-ArpPrime -IPAddress $v.IP
    }
    $endpoints = [System.Collections.Generic.List[YarboEndpoint]]::new()
    $hasRover = $false
    $hasDC = $false
    foreach ($v in $verified) {
        $mac = Get-MacForIp -IPAddress $v.IP
        $isDC = $false
        if ($mac) {
            $isDC = Test-LocallyAdministeredMac -Mac $mac
            if ($isDC) { $hasDC = $true } else { $hasRover = $true }
        } else {
            # Unknown MAC: treat as Rover to avoid wrongly recommending
            $hasRover = $true
        }
        $path = if ($isDC) { 'DC' } else { 'Rover' }
        $ep = [YarboEndpoint]::new()
        $ep.IPAddress = $v.IP
        $ep.Port = $v.Port
        $ep.Path = $path
        $ep.MacAddress = $mac ?? ''
        $ep.Hostname = $v.Hostname ?? ''
        $ep.SerialNumber = $v.SerialNumber ?? ''
        $ep.Status = 'Connected'
        $endpoints.Add($ep)
    }

    # Recommended: at most one per device (SerialNumber). Prefer DC; else one Rover (e.g. first or hostname YARBO).
    $bySerial = @{}
    foreach ($ep in $endpoints) {
        $sn = $ep.SerialNumber ?? ''
        if (-not $bySerial.ContainsKey($sn)) { $bySerial[$sn] = [System.Collections.Generic.List[YarboEndpoint]]::new() }
        $bySerial[$sn].Add($ep)
    }
    foreach ($sn in $bySerial.Keys) {
        $group = $bySerial[$sn]
        $dcs = @($group | Where-Object { $_.Path -eq 'DC' })
        $rovers = @($group | Where-Object { $_.Path -eq 'Rover' })
        if ($dcs.Count -gt 0) {
            $dcs[0].Recommended = $true
            if ($dcs.Count -gt 1) {
                foreach ($i in 1..($dcs.Count - 1)) { $dcs[$i].Recommended = $false }
            }
            foreach ($r in $rovers) { $r.Recommended = $false }
        } else {
            # No DC: recommend exactly one Rover (prefer hostname YARBO, else first)
            $toRecommend = $rovers | Where-Object { $_.Hostname -eq 'YARBO' } | Select-Object -First 1
            if (-not $toRecommend) { $toRecommend = $rovers[0] }
            foreach ($r in $rovers) { $r.Recommended = ($r -eq $toRecommend) }
        }
    }
    $bothPresent = $hasRover -and $hasDC

    # ── Console output (table + recommendation text) ────────────────────────
    # Sort into try-order: recommended first, then others (primary/secondary failover).
    $tryOrder = @($endpoints | Sort-Object { -not $_.Recommended })
    Write-Information ""
    Write-Information "Yarbo MQTT Endpoints Found:"
    Write-Information ""
    $i = 1
    foreach ($ep in $tryOrder) {
        $rec = if ($ep.Recommended) { '  ⭐ Recommended' } else { '' }
        $mac = if ($ep.MacAddress) { $ep.MacAddress } else { '(unknown – Rover/DC unclear)' }
        Write-Information ("  {0,2}  {1,-15}  {2,-5}  {3,-17}  {4,-10}{5}" -f $i, $ep.IPAddress, $ep.Path, $mac, $ep.Status, $rec)
        $i++
    }
    if ($bothPresent) {
        Write-Information ""
        Write-Information "Both endpoints reach the same MQTT broker on the Rover."
        Write-Information "The DC path is recommended — it stays connected via HaLow"
        Write-Information "when the rover is outside WiFi range."
    } elseif ($endpoints.Count -eq 1) {
        Write-Information ""
        Write-Information "Single endpoint found; use this address to connect."
    } elseif ($endpoints.Count -gt 1) {
        Write-Information ""
        Write-Information "For failover (e.g. Home Assistant), use the recommended address first;"
        Write-Information "if unreachable, try the other(s). Output order is try-order."
    }
    Write-Information ""

    # Output in try-order: recommended first, then others (primary/secondary failover).
    foreach ($ep in $tryOrder) {
        Write-Output $ep
    }
}
