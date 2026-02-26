function Watch-YarboTelemetry {
    <#
.SYNOPSIS
    Streams telemetry data to the pipeline in real time.

.DESCRIPTION
    Subscribes to the event-driven telemetry stream that Connect-Yarbo populates
    from incoming MQTT push messages (DeviceMSG at ~1-2 Hz). No polling occurs —
    the robot pushes data and the handler enqueues it for this cmdlet to consume.

    Use -IncludeHeartbeat to also receive heart_beat messages in the stream.
    Use -IncludePlanFeedback to also receive plan_feedback and recharge_feedback messages.

.PARAMETER Duration
    How long to stream. Default: 5 minutes.

.PARAMETER ThrottleMs
    Minimum interval between emitted DeviceMSG objects in milliseconds. Default: 1000.
    Heartbeat and plan_feedback messages are not throttled.

.PARAMETER Count
    Maximum number of objects to emit before stopping. 0 means unlimited.

.PARAMETER OutputFormat
    Output format: Object (default), Json (compact JSON string), or Summary (one-line text).

.PARAMETER IncludeHeartbeat
    Also emit heart_beat messages in the stream as raw PSCustomObject.

.PARAMETER IncludePlanFeedback
    Also emit plan_feedback and recharge_feedback messages in the stream as raw PSCustomObject.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Watch-YarboTelemetry -Duration 00:02:00

.EXAMPLE
    Watch-YarboTelemetry | Where-Object { $_.BatteryCapacity -lt 20 }

.EXAMPLE
    Watch-YarboTelemetry -Duration 00:05:00 | Export-YarboTelemetry -Path telemetry.csv

.EXAMPLE
    Watch-YarboTelemetry -IncludeHeartbeat -IncludePlanFeedback -Duration 00:01:00

.EXAMPLE
    Watch-YarboTelemetry -OutputFormat Json -Count 10

.LINK
    Get-YarboTelemetry
    Export-YarboTelemetry
#>
    [CmdletBinding()]
    [OutputType([YarboTelemetry], [PSCustomObject], [string])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter()]
        [TimeSpan]$Duration = [TimeSpan]::FromMinutes(5),

        [Parameter()]
        [int]$ThrottleMs = 1000,

        [Parameter()]
        [int]$Count = 0,

        [Parameter()]
        [ValidateSet('Object', 'Json', 'Summary')]
        [string]$OutputFormat = 'Object',

        [Parameter()]
        [switch]$IncludeHeartbeat,

        [Parameter()]
        [switch]$IncludePlanFeedback
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose "[Watch-YarboTelemetry] Streaming telemetry for $Duration (throttle: ${ThrottleMs}ms, format: $OutputFormat)"

        $lastEmit = [datetime]::MinValue
        $deadline = [datetime]::UtcNow + $Duration
        $emitCount = 0

        try {
            while ([datetime]::UtcNow -lt $deadline) {
                if ($Count -gt 0 -and $emitCount -ge $Count) { break }

                $remaining = [int](($deadline - [datetime]::UtcNow).TotalMilliseconds)
                if ($remaining -le 0) { break }

                # Block until an event arrives or the deadline window expires
                $waitMs = [math]::Min($remaining, 5000)
                $signaled = $conn.TelemetrySignal.Wait($waitMs)
                if (-not $signaled) { continue }

                $event = $null
                if (-not $conn.TelemetryQueue.TryDequeue([ref]$event)) { continue }

                # Filter by message type based on active switches
                $include = switch ($event.MessageType) {
                    'DeviceMSG'        { $true }
                    'HeartBeat'        { [bool]$IncludeHeartbeat }
                    'PlanFeedback'     { [bool]$IncludePlanFeedback }
                    'RechargeFeedback' { [bool]$IncludePlanFeedback }
                    default            { $false }
                }
                if (-not $include) { continue }

                # Debounce DeviceMSG frames; pass heartbeat/feedback through immediately
                if ($event.MessageType -eq 'DeviceMSG') {
                    $now = [datetime]::UtcNow
                    if (($now - $lastEmit).TotalMilliseconds -lt $ThrottleMs) { continue }
                    $lastEmit = $now
                }

                # Emit in requested format
                if ($event.MessageType -eq 'DeviceMSG') {
                    switch ($OutputFormat) {
                        'Object' {
                            $telemetry = ConvertTo-YarboTelemetry -DeviceMsg $event.Data -SerialNumber $conn.SerialNumber
                            $PSCmdlet.WriteObject($telemetry)
                        }
                        'Json' {
                            $PSCmdlet.WriteObject(($event.Data | ConvertTo-Json -Compress -Depth 10))
                        }
                        'Summary' {
                            $t = ConvertTo-YarboTelemetry -DeviceMsg $event.Data -SerialNumber $conn.SerialNumber
                            $PSCmdlet.WriteObject("$($t.Timestamp.ToString('HH:mm:ss')) | Bat:$($t.BatteryCapacity)% | State:$($t.WorkingState) | Pos:$([math]::Round($t.X,2)),$([math]::Round($t.Y,2))")
                        }
                    }
                } else {
                    # Heartbeat and feedback events: emit raw data
                    switch ($OutputFormat) {
                        'Object'  { $PSCmdlet.WriteObject($event.Data) }
                        'Json'    { $PSCmdlet.WriteObject(($event.Data | ConvertTo-Json -Compress -Depth 10)) }
                        'Summary' { $PSCmdlet.WriteObject("$($event.Timestamp.ToString('HH:mm:ss')) | Type:$($event.MessageType)") }
                    }
                }

                $emitCount++
            }
        } catch [System.Management.Automation.PipelineStoppedException] {
            # Ctrl+C — graceful exit
            Write-Verbose "[Watch-YarboTelemetry] Stream stopped by user"
        }
    }
}
