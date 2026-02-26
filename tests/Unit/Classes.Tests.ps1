#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
using module ../../src/PSYarbo/PSYarbo.psd1
<#
.SYNOPSIS
    Unit tests for PSYarbo class definitions.
#>

BeforeAll {
    $moduleRoot  = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'
    $fixturesDir = Join-Path $PSScriptRoot '..' 'Fixtures'
    $global:unitFixturesDir = $fixturesDir

    # Load classes for tests outside InModuleScope
    $classFiles = @(
        'YarboExceptions', 'YarboLightState', 'YarboCommandResult',
        'YarboTelemetry', 'YarboPlan', 'YarboSchedule', 'YarboRobot',
        'YarboConnection', 'YarboCloudSession'
    )
    foreach ($class in $classFiles) {
        . (Join-Path $moduleRoot "Classes/$class.ps1")
    }
}

Describe 'YarboPlanFeedback' {
    It 'Can be instantiated' {
        $pf = [YarboPlanFeedback]::new()
        $pf | Should -Not -BeNull
    }

    It 'Has expected properties' {
        $pf = [YarboPlanFeedback]::new()
        $pf.PlanId       = '42'
        $pf.AreaCovered  = 125.5
        $pf.Duration     = 3600
        $pf.State        = 2
        $pf.PlanId       | Should -Be '42'
        $pf.AreaCovered  | Should -Be 125.5
        $pf.Duration     | Should -Be 3600
        $pf.State        | Should -Be 2
    }

    It 'ToString includes planId and state' {
        $pf = [YarboPlanFeedback]::new()
        $pf.PlanId = '99'
        $pf.State  = 1
        $pf.ToString() | Should -BeLike '*99*'
        $pf.ToString() | Should -BeLike '*State:1*'
    }
}

Describe 'YarboConnection — new telemetry members' {
    It 'TelemetryQueue is initialized and empty' {
        $conn = [YarboConnection]::new()
        # Use -ne check to avoid PowerShell enumerating the ConcurrentQueue when piping
        ($null -ne $conn.TelemetryQueue) | Should -BeTrue
        $conn.TelemetryQueue.Count | Should -Be 0
    }

    It 'TelemetrySignal is initialized' {
        $conn = [YarboConnection]::new()
        ($null -ne $conn.TelemetrySignal) | Should -BeTrue
    }

    It 'TelemetryLog is initialized and empty' {
        $conn = [YarboConnection]::new()
        # Use -ne check to avoid PowerShell enumerating the List when piping
        ($null -ne $conn.TelemetryLog) | Should -BeTrue
        $conn.TelemetryLog.Count | Should -Be 0
    }

    It 'LastPlanFeedback starts null' {
        $conn = [YarboConnection]::new()
        $conn.LastPlanFeedback | Should -BeNullOrEmpty
    }

    It 'LastRechargeFeedback starts null' {
        $conn = [YarboConnection]::new()
        $conn.LastRechargeFeedback | Should -BeNullOrEmpty
    }

    It 'Dispose cleans up TelemetrySignal' {
        $conn = [YarboConnection]::new()
        $conn.Dispose()
        $conn.TelemetrySignal | Should -BeNull
    }
}

AfterAll {
    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
}
