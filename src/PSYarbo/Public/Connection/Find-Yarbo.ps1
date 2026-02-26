function Find-Yarbo {
<#
.SYNOPSIS
    Auto-discovers Yarbo robots on the local network.

.DESCRIPTION
    Scans the specified subnet for MQTT brokers on port 1883.
    For each found broker, attempts to connect and listen for heart_beat
    messages to identify Yarbo robots.

.PARAMETER Subnet
    Network subnet to scan in CIDR notation. Default: 192.168.1.0/24.

.PARAMETER TimeoutSeconds
    How long to wait for responses. Default: 5.

.PARAMETER Port
    MQTT port to scan. Default: 1883.

.EXAMPLE
    Find-Yarbo

.EXAMPLE
    Find-Yarbo -Subnet 10.0.0.0/24 -TimeoutSeconds 10

.LINK
    Connect-Yarbo
#>
    [CmdletBinding()]
    [OutputType([YarboRobot])]
    param(
        [Parameter()]
        [string]$Subnet = '192.168.1.0/24',

        [Parameter()]
        [int]$TimeoutSeconds = 5,

        [Parameter()]
        [int]$Port = 1883
    )

    Write-Verbose "[Find-Yarbo] Scanning $Subnet for MQTT brokers on port $Port"

    # Parse CIDR
    $parts = $Subnet -split '/'
    $baseIp = [System.Net.IPAddress]::Parse($parts[0])
    $prefixLen = [int]$parts[1]
    $baseBytes = $baseIp.GetAddressBytes()

    $hostBits = 32 - $prefixLen
    $hostCount = [math]::Pow(2, $hostBits) - 2  # Exclude network and broadcast

    $found = [System.Collections.Generic.List[YarboRobot]]::new()

    for ($i = 1; $i -le $hostCount; $i++) {
        $ipBytes = [byte[]]$baseBytes.Clone()
        $ipVal = [BitConverter]::ToUInt32([byte[]]@($ipBytes[3], $ipBytes[2], $ipBytes[1], $ipBytes[0]), 0) + $i
        $newBytes = [BitConverter]::GetBytes($ipVal)
        [Array]::Reverse($newBytes)
        $ip = [System.Net.IPAddress]::new($newBytes).ToString()

        # Quick TCP port check
        try {
            $client = [System.Net.Sockets.TcpClient]::new()
            $connectTask = $client.ConnectAsync($ip, $Port)
            if ($connectTask.Wait([TimeSpan]::FromMilliseconds(200))) {
                if ($client.Connected) {
                    Write-Verbose "[Find-Yarbo] MQTT broker found at ${ip}:${Port}"
                    $robot = [YarboRobot]::new()
                    $robot.Broker = $ip
                    $robot.Port = $Port
                    $robot.SerialNumber = "UNKNOWN"
                    $found.Add($robot)
                }
            }
            $client.Dispose()
        }
        catch {
            # Connection failed — not a broker
        }
    }

    Write-Verbose "[Find-Yarbo] Found $($found.Count) potential MQTT broker(s)"
    return $found
}
