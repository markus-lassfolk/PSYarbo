function ConvertTo-ZlibPayload {
    <#
    .SYNOPSIS
        Compresses a hashtable payload to zlib-compressed JSON bytes.
    #>
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Payload
    )

    $json = $Payload | ConvertTo-Json -Compress -Depth 10
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

    $ms = [System.IO.MemoryStream]::new()
    try {
        $zlib = [System.IO.Compression.ZLibStream]::new($ms, [System.IO.Compression.CompressionLevel]::Optimal, $true)
        try {
            $zlib.Write($bytes, 0, $bytes.Length)
        } finally {
            $zlib.Dispose()
        }
        return $ms.ToArray()
    } finally {
        $ms.Dispose()
    }
}

function ConvertFrom-ZlibPayload {
    <#
    .SYNOPSIS
        Decompresses zlib-compressed bytes to a PSCustomObject.
        Falls back to plain JSON if zlib decompression fails.
    #>
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Data
    )

    try {
        $ms = [System.IO.MemoryStream]::new($Data)
        try {
            $zlib = [System.IO.Compression.ZLibStream]::new($ms, [System.IO.Compression.CompressionMode]::Decompress)
            try {
                $reader = [System.IO.StreamReader]::new($zlib, [System.Text.Encoding]::UTF8)
                try {
                    return $reader.ReadToEnd() | ConvertFrom-Json
                } finally {
                    $reader.Dispose()
                }
            } finally {
                $zlib.Dispose()
            }
        } finally {
            $ms.Dispose()
        }
    }
    catch {
        # Fallback: try parsing as plain JSON (heart_beat may not be compressed)
        try {
            return [System.Text.Encoding]::UTF8.GetString($Data) | ConvertFrom-Json
        }
        catch {
            Write-Warning "Failed to decode payload: $($_.Exception.Message)"
            return $null
        }
    }
}
