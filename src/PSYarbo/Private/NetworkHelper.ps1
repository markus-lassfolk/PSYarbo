# Returns CIDR subnets for all local IPv4 addresses (LAN, Wi‑Fi, etc.) so discovery can scan "my networks" by default.

function Get-PSYarboSubnetIpList {
    <#
    .SYNOPSIS
        Generates a list of host IPs from CIDR subnets for network scanning.
    
    .PARAMETER Subnets
        Array of CIDR subnet strings (e.g., '192.0.2.0/24').
    
    .PARAMETER MaxHosts
        Maximum number of host IPs to generate across all subnets.
    
    .PARAMETER ValidateUserInput
        When true, throws an exception for invalid subnet prefixes instead of silently skipping them.
    
    .OUTPUTS
        [string[]] Array of IP addresses to scan.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Subnets,
        
        [Parameter(Mandatory)]
        [int]$MaxHosts,
        
        [Parameter()]
        [switch]$ValidateUserInput
    )
    
    $ipList = [System.Collections.Generic.List[string]]::new()
    $remaining = $MaxHosts
    
    foreach ($oneSubnet in $Subnets) {
        if ($remaining -le 0) { break }
        $parts = $oneSubnet -split '/'
        if ($parts.Count -lt 2) { continue }
        $prefixLen = [int]$parts[1]
        if ($prefixLen -lt 16 -or $prefixLen -gt 30) {
            if ($ValidateUserInput) {
                if ($prefixLen -lt 16) {
                    throw [System.ArgumentException]::new(
                        "Subnet prefix /$prefixLen is too large for safety. Use /16 or longer."
                    )
                }
                if ($prefixLen -gt 30) {
                    throw [System.ArgumentException]::new(
                        "Subnet prefix /$prefixLen has no scannable host addresses. Use /30 or shorter."
                    )
                }
            }
            continue
        }
        $baseIp = [System.Net.IPAddress]::Parse($parts[0].Trim())
        $baseBytes = $baseIp.GetAddressBytes()
        [Array]::Reverse($baseBytes)
        $hostBits = 32 - $prefixLen
        $baseVal = [System.BitConverter]::ToUInt32($baseBytes, 0)
        $baseVal = [uint32]($baseVal -band ([uint32]::MaxValue -shl $hostBits))
        $baseBytes = [System.BitConverter]::GetBytes($baseVal)
        $maxInSubnet = [math]::Pow(2, $hostBits) - 2
        $take = [math]::Min([int]$maxInSubnet, $remaining)
        for ($i = 1; $i -le $take; $i++) {
            $ipVal = $baseVal + $i
            $newBytes = [System.BitConverter]::GetBytes([uint32]$ipVal)
            [Array]::Reverse($newBytes)
            $ipList.Add([System.Net.IPAddress]::new($newBytes).ToString())
        }
        $remaining -= $take
    }
    
    return $ipList.ToArray()
}

function Get-PSYarboLocalSubnet {
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
        Write-Debug "Get-PSYarboLocalSubnet: $($_.Exception.Message)"
    }
}
