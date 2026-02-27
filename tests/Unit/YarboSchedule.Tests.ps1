#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Unit tests for YarboSchedule class (GetDays, ToString, properties).
    Loads only the Schedule class to avoid full module.
#>

BeforeAll {
    $scriptRoot = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'
    . (Join-Path $scriptRoot 'Classes' 'YarboSchedule.ps1')
}

Describe 'YarboSchedule' {
    It 'Can be instantiated' {
        $s = [YarboSchedule]::new()
        $s | Should -Not -BeNull
    }

    It 'GetDays returns empty when WeekDay is 0' {
        $s = [YarboSchedule]::new()
        $s.WeekDay = 0
        $days = $s.GetDays()
        $days.Length | Should -Be 0
    }

    It 'GetDays returns single day when WeekDay is 1 (Sunday)' {
        $s = [YarboSchedule]::new()
        $s.WeekDay = 1
        $days = $s.GetDays()
        $days.Length | Should -Be 1
        $days[0].ToString() | Should -Be 'Sunday'
    }

    It 'GetDays returns all days when WeekDay is 127' {
        $s = [YarboSchedule]::new()
        $s.WeekDay = 127
        $days = $s.GetDays()
        $days.Length | Should -Be 7
    }

    It 'ToString includes name and time range' {
        $s = [YarboSchedule]::new()
        $s.Name = 'Morning'
        $s.StartTime = '08:00'
        $s.EndTime = '10:00'
        $s.WeekDay = 127
        $s.Enabled = $true
        $str = $s.ToString()
        $str | Should -BeLike '*Morning*'
        $str | Should -BeLike '*08:00*10:00*'
        $str | Should -BeLike '*Daily*'
    }
}
