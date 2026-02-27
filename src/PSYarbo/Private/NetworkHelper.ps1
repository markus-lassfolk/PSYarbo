# Returns CIDR subnets for all local IPv4 addresses (LAN, Wi‑Fi, etc.) so discovery can scan "my networks" by default.

function Get-PSYarboLocalSubnets {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    try {
        $adapters = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()
        foreach ($a in $adapters) {
            if ($a.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up) { continue }
            if ($a.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback) { continue }
            $props = $a.GetIPProperties()
            foreach ($addr in $props.UnicastAddresses) {
                if ($addr.Address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { continue }
                $ip = $addr.Address
                $plen = $addr.PrefixLength
                if ($plen -lt 16 -or $plen -gt 30) { continue }
                $bytes = $ip.GetAddressBytes()
                [Array]::Reverse($bytes)
                $val = [System.BitConverter]::ToUInt32($bytes, 0)
                $mask = [uint32]::MaxValue -shl (32 - $plen)
                $netVal = $val -band $mask
                $netBytes = [System.BitConverter]::GetBytes([uint32]$netVal)
                [Array]::Reverse($netBytes)
                $netIp = [System.Net.IPAddress]::new($netBytes)
                $cidr = "$($netIp)/$plen"
                if ($addr.Address.ToString().StartsWith('169.254.')) { continue }
                if (-not $seen.Contains($cidr)) {
                    $null = $seen.Add($cidr)
                    $cidr
                }
            }
        }
    } catch {
        Write-Debug "Get-PSYarboLocalSubnets: $($_.Exception.Message)"
    }
}
