class YarboSchedule {
    [int]$Id
    [string]$Name
    [int]$PlanId
    [bool]$Enabled
    [int]$ScheduleType
    [string]$StartTime
    [string]$EndTime
    [int]$WeekDay
    [int]$IntervalTime
    [bool]$IsWeatherSchedule
    [int]$ReturnMethod
    [int]$Times
    [string]$Timezone

    [DayOfWeek[]] GetDays() {
        $days = [System.Collections.Generic.List[DayOfWeek]]::new()
        # Bitmask: bit 0 = Sunday, bit 1 = Monday, etc.
        for ($i = 0; $i -lt 7; $i++) {
            if ($this.WeekDay -band (1 -shl $i)) {
                $days.Add([DayOfWeek]$i)
            }
        }
        return $days.ToArray()
    }

    [string] ToString() {
        $days = if ($this.WeekDay -eq 127) { 'Daily' } else { ($this.GetDays() | ForEach-Object { $_.ToString().Substring(0, 3) }) -join ',' }
        return "$($this.Name) - $($this.StartTime)-$($this.EndTime) $days $(if($this.Enabled){'✓'}else{'✗'})"
    }
}
