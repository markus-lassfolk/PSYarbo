function Get-YarboSchedule {
<#
.SYNOPSIS
    Retrieves scheduled plan executions.

.DESCRIPTION
    Sends read_schedules to get all configured schedules.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboSchedule

.EXAMPLE
    Get-YarboSchedule | Format-Table

.LINK
    Set-YarboSchedule
    Get-YarboPlan
#>
    [CmdletBinding()]
    [OutputType([YarboSchedule])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboSchedule] Routing via local MQTT → read_schedules")
        $result = Send-MqttCommand -Connection $conn -Command 'read_schedules' -Payload @{}

        if ($null -eq $result -or -not $result.Success) { return }

        foreach ($item in $result.Data) {
            $sched = [YarboSchedule]::new()
            $sched.Id = $item.id
            $sched.Name = $item.name
            $sched.PlanId = $item.plan_id
            $sched.Enabled = [bool]$item.enable
            $sched.ScheduleType = $item.schedule_type
            $sched.StartTime = $item.start_time
            $sched.EndTime = $item.end_time
            $sched.WeekDay = $item.week_day
            $sched.IntervalTime = $item.interval_time
            $sched.IsWeatherSchedule = [bool]$item.is_weather_schedule
            $sched.ReturnMethod = $item.return_method
            $sched.Times = $item.times
            $sched.Timezone = $item.timezone
            $sched
        }
    }
}
