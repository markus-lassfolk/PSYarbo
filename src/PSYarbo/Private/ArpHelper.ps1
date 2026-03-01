# Private helpers for MAC resolution and locally-administered check (issue #30).
# Get-MacForIp: Windows (Get-NetNeighbor), Linux (/proc/net/arp, arp -n), macOS (arp -a).
# Invoke-ArpPrime: ping or TCP touch so the OS ARP table has an entry before lookup.

function Invoke-ArpPrime {
    <#
    .SYNOPSIS
        Ensures the given IP has an ARP entry (pings once) so Get-MacForIp can resolve the MAC.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$IPAddress
    )
    if (-not $IPAddress -or $IPAddress -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') { return }
    try {
        if ($IsWindows) {
            $null = Test-Connection -ComputerName $IPAddress -Count 1 -Quiet -ErrorAction SilentlyContinue
        } else {
            $null = ping -c 1 -W 1 $IPAddress 2>$null
        }
    } catch {
        Write-Debug "Invoke-ArpPrime $IPAddress : $($_.Exception.Message)"
    }
}

function Get-MacForIp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$IPAddress
    )
    if (-not $IPAddress -or $IPAddress -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
        return $null
    }
    try {
        if ($IsWindows) {
            try {
                $neighbor = Get-NetNeighbor -RemoteIPAddress $IPAddress -ErrorAction Stop
                if ($neighbor -and $neighbor.LinkLayerAddress) {
                    return Format-MacAddress $neighbor.LinkLayerAddress
                }
            } catch {
                Write-Debug "Get-NetNeighbor failed, trying arp: $($_.Exception.Message)"
            }
            $arpOut = arp -a 2>$null
            $esc = [regex]::Escape($IPAddress)
            if ($arpOut -match "\b$esc\b") {
                $line = $arpOut | Where-Object { $_ -match "\b$esc\b" } | Select-Object -First 1
                if ($line -match '([0-9a-fA-F]{2}[:-][0-9a-fA-F]{2}[:-][0-9a-fA-F]{2}[:-][0-9a-fA-F]{2}[:-][0-9a-fA-F]{2}[:-][0-9a-fA-F]{2})') {
                    return Format-MacAddress $matches[1]
                }
            }
            return $null
        }
        # Linux: /proc/net/arp — columns: IP, HW type, Flags, HW addr, Mask, Device
        $arpPath = '/proc/net/arp'
        if (Test-Path $arpPath) {
            $esc = [regex]::Escape($IPAddress)
            $line = Get-Content $arpPath -ErrorAction SilentlyContinue | Where-Object { $_ -match "^\s*$esc\s+" } | Select-Object -First 1
            if ($line -match '^\s*\S+\s+\S+\s+\S+\s+(\S+)\s+') {
                $mac = $matches[1].Trim()
                if ($mac -and $mac -ne '00:00:00:00:00:00') {
                    return Format-MacAddress $mac
                }
            }
        }
        # Fallback: arp -n (Linux) or arp -a (macOS)
        $arpOut = arp -n 2>$null
        if (-not $arpOut) { $arpOut = arp -a 2>$null }
        if ($arpOut) {
            $esc = [regex]::Escape($IPAddress)
            $line = $arpOut | Where-Object { $_ -match "\b$esc\b" } | Select-Object -First 1
            if ($line -match '([0-9a-fA-F]{1,2}[:-][0-9a-fA-F]{1,2}[:-][0-9a-fA-F]{1,2}[:-][0-9a-fA-F]{1,2}[:-][0-9a-fA-F]{1,2}[:-][0-9a-fA-F]{1,2})') {
                return Format-MacAddress $matches[1]
            }
        }
    } catch {
        Write-Debug "Get-MacForIp $IPAddress : $($_.Exception.Message)"
    }
    return $null
}

function Format-MacAddress {
    param([string]$Mac)
    if (-not $Mac) { return $null }
    $octets = $Mac -split '[:-]'
    if ($octets.Count -ne 6) { return $Mac }
    $normalized = $octets | ForEach-Object { $_.PadLeft(2, '0') }
    return $normalized -join ':'
}

function Test-LocallyAdministeredMac {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Mac
    )
    if (-not $Mac) { return $false }
    $octets = $Mac -split '[:-]'
    if ($octets.Count -lt 1 -or -not $octets[0]) { return $false }
    try {
        $firstOctet = [Convert]::ToByte($octets[0].PadLeft(2, '0'), 16)
        return ($firstOctet -band 0x02) -eq 0x02
    } catch {
        return $false
    }
}
