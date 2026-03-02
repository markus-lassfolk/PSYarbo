#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Integration tests: Find Yarbo, Connect, then run all local Get-Yarbo* cmdlets.
    Run on a machine that can reach the robot (e.g. Windows on same LAN as the mower).
    The robot should be powered on; if it is sleeping, the test tries Resume-Yarbo after connect.
    Skip integration in CI: Invoke-Pester ./tests -ExcludeTag Integration
    Run only this file: Invoke-Pester ./tests/Integration/FindConnectGetYarbo.Integration.Tests.ps1
#>

BeforeAll {
    $moduleRoot = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'
    $manifestPath = Join-Path $moduleRoot 'PSYarbo.psd1'
    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
    Import-Module -Name $manifestPath -Force -WarningAction SilentlyContinue
}

Describe 'Find-Yarbo and Connect-Yarbo' -Tag Integration {
    It 'Find-Yarbo returns at least one YarboRobot' {
        $found = Find-Yarbo -TimeoutSeconds 8 -ErrorAction Stop
        $found | Should -Not -BeNullOrEmpty
        $found[0].SerialNumber | Should -Not -BeNullOrEmpty
        $found[0].Broker | Should -Not -BeNullOrEmpty
        $found[0].PSObject.TypeNames[0] | Should -BeLike '*YarboRobot*'
    }

    It 'Connect-Yarbo succeeds with first Find-Yarbo result' {
        $robot = Find-Yarbo -TimeoutSeconds 8 -ErrorAction Stop | Select-Object -First 1
        $robot | Should -Not -BeNullOrEmpty
        $conn = $robot | Connect-Yarbo -TimeoutSeconds 10 -ErrorAction Stop
        $conn | Should -Not -BeNullOrEmpty
        $conn.Broker | Should -Be $robot.Broker
        $conn.SerialNumber | Should -Be $robot.SerialNumber
        $conn.PSObject.TypeNames[0] | Should -BeLike '*YarboConnection*'
        $script:YarboConnection = $conn
    }
}

Describe 'Get-Yarbo* (local MQTT)' -Tag Integration {
    BeforeAll {
        if (-not $script:YarboConnection) {
            $robot = Find-Yarbo -TimeoutSeconds 8 -ErrorAction Stop | Select-Object -First 1
            $script:YarboConnection = $robot | Connect-Yarbo -TimeoutSeconds 10 -ErrorAction Stop
        }
        $script:Conn = $script:YarboConnection
        # Wake robot if it was sleeping (controller timed out); then allow a short delay for it to respond
        Resume-Yarbo -Connection $script:Conn -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 4
    }

    It 'Get-YarboStatus returns YarboRobot with expected properties' {
        $status = Get-YarboStatus -Connection $script:Conn -ErrorAction Stop
        $status | Should -Not -BeNullOrEmpty
        $status.PSObject.TypeNames[0] | Should -BeLike '*YarboRobot*'
        $status.SerialNumber | Should -Not -BeNullOrEmpty
        $status.PSObject.Properties['Battery'] | Should -Not -BeNullOrEmpty
        $status.PSObject.Properties['State'] | Should -Not -BeNullOrEmpty
    }

    It 'Get-YarboRobot returns YarboRobot' {
        $r = Get-YarboRobot -Connection $script:Conn -ErrorAction Stop
        $r | Should -Not -BeNullOrEmpty
        $r.PSObject.TypeNames[0] | Should -BeLike '*YarboRobot*'
    }

    It 'Get-YarboBattery returns a numeric value' {
        $bat = Get-YarboBattery -Connection $script:Conn -ErrorAction Stop
        $bat | Should -Not -BeNullOrEmpty
        $bat | Should -BeIn (0..100)
    }

    It 'Get-YarboFirmware returns an object with version info' {
        $fw = Get-YarboFirmware -Connection $script:Conn -ErrorAction Stop
        $fw | Should -Not -BeNullOrEmpty
        $fw.PSObject.Properties | Should -Not -BeNullOrEmpty
    }

    It 'Get-YarboGlobalParams returns an object' {
        $gp = Get-YarboGlobalParams -Connection $script:Conn -ErrorAction Stop
        $gp | Should -Not -BeNullOrEmpty
    }

    It 'Get-YarboMap returns map data (or empty if no map)' {
        $map = Get-YarboMap -Connection $script:Conn -ErrorAction SilentlyContinue
        # May be null/empty if robot has no map
        if ($map) {
            $map.PSObject.Properties | Should -Not -BeNullOrEmpty
        }
    }

    It 'Get-YarboPlan returns plan list (array)' {
        $plans = Get-YarboPlan -Connection $script:Conn -ErrorAction Stop
        $plans | Should -Not -BeNullOrEmpty
        $plans -is [Array] | Should -BeTrue
        if ($plans.Count -gt 0) {
            $plans[0].PSObject.TypeNames[0] | Should -BeLike '*YarboPlan*'
        }
    }

    It 'Get-YarboSchedule returns schedule list (array or empty)' {
        $schedules = Get-YarboSchedule -Connection $script:Conn -ErrorAction SilentlyContinue
        if ($null -eq $schedules) { $schedules = @() }
        $schedules -is [Array] | Should -BeTrue
        if ($schedules.Count -gt 0) {
            $schedules[0].PSObject.TypeNames[0] | Should -BeLike '*YarboSchedule*'
        }
    }

    It 'Get-YarboTelemetry returns YarboTelemetry' {
        $tel = Get-YarboTelemetry -Connection $script:Conn -ErrorAction Stop
        $tel | Should -Not -BeNullOrEmpty
        $tel.PSObject.TypeNames[0] | Should -BeLike '*YarboTelemetry*'
        $tel.PSObject.Properties['Battery'] | Should -Not -BeNullOrEmpty
        $tel.PSObject.Properties['State'] | Should -Not -BeNullOrEmpty
    }

    It 'Get-YarboLog returns log entries (array)' {
        $log = Get-YarboLog -Connection $script:Conn -Last 5 -ErrorAction Stop
        $log | Should -Not -BeNullOrEmpty
        $log -is [Array] | Should -BeTrue
    }
}

Describe 'Disconnect-Yarbo' -Tag Integration {
    It 'Disconnect-Yarbo runs without error' {
        if ($script:YarboConnection) {
            { Disconnect-Yarbo -Connection $script:YarboConnection -ErrorAction Stop } | Should -Not -Throw
            $script:YarboConnection = $null
        }
    }
}
