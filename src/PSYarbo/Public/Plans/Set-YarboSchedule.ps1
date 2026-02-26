function Set-YarboSchedule {
<#
.SYNOPSIS
    Updates a schedule configuration.

.DESCRIPTION
    Sends save_schedule to update an existing schedule's properties.

.PARAMETER ScheduleId
    The schedule ID to update.

.PARAMETER Enabled
    Enable or disable the schedule.

.PARAMETER StartTime
    Start time in HH:mm:ss format.

.PARAMETER EndTime
    End time in HH:mm:ss format.

.PARAMETER Days
    Days of the week. Converted to bitmask (127 = all days).

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboSchedule -ScheduleId 1 -Enabled $true -StartTime "06:00:00" -EndTime "08:00:00"

.LINK
    Get-YarboSchedule
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboSchedule])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory)]
        [int]$ScheduleId,

        [Parameter()]
        [bool]$Enabled,

        [Parameter()]
        [string]$StartTime,

        [Parameter()]
        [string]$EndTime,

        [Parameter()]
        [DayOfWeek[]]$Days
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection

        # Build payload from provided parameters
        $payload = @{ id = $ScheduleId }
        if ($PSBoundParameters.ContainsKey('Enabled')) { $payload.enable = $Enabled }
        if ($StartTime) { $payload.start_time = $StartTime }
        if ($EndTime) { $payload.end_time = $EndTime }
        if ($Days) {
            $bitmask = 0
            foreach ($day in $Days) { $bitmask = $bitmask -bor (1 -shl [int]$day) }
            $payload.week_day = $bitmask
        }

        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Update schedule $ScheduleId")) {
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboSchedule] Routing via local MQTT → save_schedule")
            $result = Send-MqttCommand -Connection $conn -Command 'save_schedule' -Payload $payload
            if ($result -and $result.Success) {
                return Get-YarboSchedule -Connection $conn | Where-Object { $_.Id -eq $ScheduleId }
            }
        }
    }
}
