function Export-YarboTelemetry {
    <#
.SYNOPSIS
    Exports telemetry data to a file.

.DESCRIPTION
    Accepts YarboTelemetry objects from the pipeline and writes them
    to CSV, JSON, or JSONL format.

.PARAMETER Telemetry
    Telemetry objects to export (pipeline input).

.PARAMETER Path
    Output file path.

.PARAMETER Format
    Output format: CSV, JSON, or JSONL. Default: CSV.

.PARAMETER Append
    Append to existing file instead of overwriting.

.EXAMPLE
    Watch-YarboTelemetry -Duration 00:05:00 | Export-YarboTelemetry -Path telemetry.csv

.EXAMPLE
    Get-YarboTelemetry | Export-YarboTelemetry -Path snapshot.json -Format JSON

.LINK
    Watch-YarboTelemetry
    Get-YarboTelemetry
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [YarboTelemetry[]]$Telemetry,

        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter()]
        [ValidateSet('CSV', 'JSON', 'JSONL')]
        [string]$Format = 'CSV',

        [Parameter()]
        [switch]$Append
    )

    begin {
        $allData = [System.Collections.Generic.List[YarboTelemetry]]::new()
    }

    process {
        foreach ($t in $Telemetry) {
            $allData.Add($t)

            # For JSONL, write incrementally
            if ($Format -eq 'JSONL') {
                $line = $t | Select-Object * -ExcludeProperty RawMessage | ConvertTo-Json -Compress
                if ($Append -or $allData.Count -gt 1) {
                    $line | Add-Content -Path $Path -Encoding UTF8
                } else {
                    $line | Set-Content -Path $Path -Encoding UTF8
                }
            }
        }
    }

    end {
        if ($Format -eq 'CSV') {
            $export = $allData | Select-Object * -ExcludeProperty RawMessage
            if ($Append) {
                $export | Export-Csv -Path $Path -Append -NoTypeInformation
            } else {
                $export | Export-Csv -Path $Path -NoTypeInformation
            }
        } elseif ($Format -eq 'JSON') {
            $json = $allData | Select-Object * -ExcludeProperty RawMessage | ConvertTo-Json -Depth 5
            if ($Append -and (Test-Path $Path)) {
                $existing = Get-Content -Path $Path -Raw | ConvertFrom-Json
                $combined = @($existing) + @($allData | Select-Object * -ExcludeProperty RawMessage)
                $combined | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
            } else {
                $json | Set-Content -Path $Path -Encoding UTF8
            }
        }
        # JSONL already written incrementally

        Write-Verbose "[Export-YarboTelemetry] Exported $($allData.Count) record(s) to $Path ($Format)"
    }
}
