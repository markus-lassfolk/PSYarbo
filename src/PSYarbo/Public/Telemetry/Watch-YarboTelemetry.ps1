function Watch-YarboTelemetry {
    <#
.SYNOPSIS
    Streams telemetry data to the pipeline in real time.

.DESCRIPTION
    Subscribes to DeviceMSG and emits YarboTelemetry objects until the
    duration expires or Ctrl+C is pressed.

.PARAMETER Duration
    How long to stream. Default: 5 minutes.

.PARAMETER ThrottleMs
    Minimum interval between emitted objects in milliseconds. Default: 1000.

.PARAMETER Raw
    Emit raw PSCustomObject instead of YarboTelemetry.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Watch-YarboTelemetry -Duration 00:02:00

.EXAMPLE
    Watch-YarboTelemetry | Where-Object { $_.BatteryCapacity -lt 20 }

.EXAMPLE
    Watch-YarboTelemetry -Duration 00:05:00 | Export-YarboTelemetry -Path telemetry.csv

.LINK
    Get-YarboTelemetry
    Export-YarboTelemetry
#>
    [CmdletBinding()]
    [OutputType([YarboTelemetry])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter()]
        [TimeSpan]$Duration = [TimeSpan]::FromMinutes(5),

        [Parameter()]
        [int]$ThrottleMs = 1000,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose "[Watch-YarboTelemetry] Streaming telemetry for $Duration (throttle: ${ThrottleMs}ms)"

        $lastEmit = [datetime]::MinValue
        $deadline = [datetime]::UtcNow + $Duration

        # We rely on the connection's existing DeviceMSG subscription
        # Poll the connection's Robot property for updates
        try {
            while ([datetime]::UtcNow -lt $deadline) {
                # Request fresh telemetry
                $result = Send-MqttCommand -Connection $conn -Command 'get_device_msg' -Payload @{} -TimeoutMs 3000

                if ($result -and $result.Success -and $result.Data) {
                    $now = [datetime]::UtcNow
                    if (($now - $lastEmit).TotalMilliseconds -ge $ThrottleMs) {
                        if ($Raw) {
                            $PSCmdlet.WriteObject($result.Data)
                        } else {
                            $telemetry = ConvertTo-YarboTelemetry -DeviceMsg $result.Data -SerialNumber $conn.SerialNumber
                            $PSCmdlet.WriteObject($telemetry)
                        }
                        $lastEmit = $now
                    }
                }

                # Sleep for throttle interval
                [System.Threading.Thread]::Sleep([math]::Max(100, $ThrottleMs - 500))
            }
        } catch [System.Management.Automation.PipelineStoppedException] {
            # Ctrl+C — graceful exit
            Write-Verbose "[Watch-YarboTelemetry] Stream stopped by user"
        }
    }
}
