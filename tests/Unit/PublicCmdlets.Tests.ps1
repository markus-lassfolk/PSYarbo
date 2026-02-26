#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
using module ../../src/PSYarbo/PSYarbo.psd1
<#
.SYNOPSIS
    Unit tests for new public cmdlets added in issues #7-16.
#>

BeforeAll {
    $moduleRoot  = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'
    $helpersDir  = Join-Path $PSScriptRoot '..' 'Helpers'
    $fixturesDir = Join-Path $PSScriptRoot '..' 'Fixtures'

    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
    Import-Module -Name (Join-Path $moduleRoot 'PSYarbo.psd1') -Force -WarningAction SilentlyContinue

    # Load class files for test-scope use
    $classFiles = @(
        'YarboExceptions', 'YarboLightState', 'YarboCommandResult',
        'YarboTelemetry', 'YarboPlan', 'YarboSchedule', 'YarboRobot',
        'YarboConnection', 'YarboCloudSession'
    )
    foreach ($cf in $classFiles) { . (Join-Path $moduleRoot "Classes/$cf.ps1") }
}

InModuleScope PSYarbo {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Helpers' 'MockMqttClient.ps1')
        $script:fixturesDir = Join-Path $PSScriptRoot '..' 'Fixtures'
    }

    Describe 'Send-YarboReturnToDock' {
        It 'Is exported from the module' {
            Get-Command -Name 'Send-YarboReturnToDock' | Should -Not -BeNullOrEmpty
        }

        It 'Has alias Return-YarboToDock' {
            Get-Alias -Name 'Return-YarboToDock' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Has Medium ConfirmImpact' {
            $cmd = Get-Command Send-YarboReturnToDock
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'Medium'
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Send-YarboReturnToDock
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Synopsis | Should -Not -Be 'Send-YarboReturnToDock'
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Stop-YarboManualDrive — HardStop parameter' {
        It 'Has -HardStop switch parameter' {
            $cmd = Get-Command Stop-YarboManualDrive
            $cmd.Parameters.ContainsKey('HardStop') | Should -BeTrue
        }

        It '-HardStop is a SwitchParameter' {
            $cmd = Get-Command Stop-YarboManualDrive
            $cmd.Parameters['HardStop'].ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
        }
    }

    Describe 'Get-YarboGlobalParams' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboGlobalParams' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example' {
            $help = Get-Help Get-YarboGlobalParams
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Set-YarboGlobalParams' {
        It 'Is exported from the module' {
            Get-Command -Name 'Set-YarboGlobalParams' | Should -Not -BeNullOrEmpty
        }

        It 'Has ConfirmImpact High' {
            $cmd = Get-Command Set-YarboGlobalParams
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }

        It 'Has mandatory Parameters parameter' {
            $cmd = Get-Command Set-YarboGlobalParams
            $cmd.Parameters['Parameters'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
        }
    }

    Describe 'Watch-YarboTelemetry — new parameters' {
        It 'Has -Count parameter' {
            $cmd = Get-Command Watch-YarboTelemetry
            $cmd.Parameters.ContainsKey('Count') | Should -BeTrue
        }

        It 'Has -OutputFormat parameter with correct valid values' {
            $cmd = Get-Command Watch-YarboTelemetry
            $cmd.Parameters.ContainsKey('OutputFormat') | Should -BeTrue
            $validateSet = $cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Object'
            $validateSet.ValidValues | Should -Contain 'Json'
            $validateSet.ValidValues | Should -Contain 'Summary'
        }

        It 'Has -IncludeHeartbeat switch' {
            $cmd = Get-Command Watch-YarboTelemetry
            $cmd.Parameters.ContainsKey('IncludeHeartbeat') | Should -BeTrue
            $cmd.Parameters['IncludeHeartbeat'].ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
        }

        It 'Has -IncludePlanFeedback switch' {
            $cmd = Get-Command Watch-YarboTelemetry
            $cmd.Parameters.ContainsKey('IncludePlanFeedback') | Should -BeTrue
            $cmd.Parameters['IncludePlanFeedback'].ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
        }
    }

    Describe 'Get-YarboLog — filter values' {
        It 'Filter ValidateSet includes Received' {
            $cmd = Get-Command Get-YarboLog
            $vs = $cmd.Parameters['Filter'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $vs.ValidValues | Should -Contain 'Received'
        }

        It 'Filter ValidateSet includes Telemetry' {
            $cmd = Get-Command Get-YarboLog
            $vs = $cmd.Parameters['Filter'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $vs.ValidValues | Should -Contain 'Telemetry'
        }

        It 'Filter Telemetry returns TelemetryLog entries from mock connection' {
            $conn = New-MockYarboConnection
            $fixture = Get-Content (Join-Path $script:fixturesDir 'DeviceMSG-sample.json') | ConvertFrom-Json
            $conn.TelemetryLog.Add([PSCustomObject]@{
                Timestamp   = [datetime]::UtcNow
                MessageType = 'DeviceMSG'
                Direction   = 'Pushed'
                Topic       = 'snowbot/TEST-SN/device/DeviceMSG'
            })
            $script:DefaultConnection = $conn
            $entries = Get-YarboLog -Filter Telemetry
            $entries.Count | Should -BeGreaterThan 0
            $entries[0].MessageType | Should -Be 'DeviceMSG'
            $script:DefaultConnection = $null
            $conn.Dispose()
        }
    }

    Describe 'Watch-YarboTelemetry — event-driven consumption' {
        It 'Emits one YarboTelemetry from a queued DeviceMSG event' {
            $conn = New-MockYarboConnection
            $fixture = Get-Content (Join-Path $script:fixturesDir 'DeviceMSG-sample.json') | ConvertFrom-Json
            Push-MockTelemetryEvent -Connection $conn -MessageType 'DeviceMSG' -Data $fixture

            $script:DefaultConnection = $conn
            $result = Watch-YarboTelemetry -Duration ([TimeSpan]::FromSeconds(2)) -Count 1
            $script:DefaultConnection = $null
            $conn.Dispose()

            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [YarboTelemetry]
            $result.BatteryCapacity | Should -Be 83
        }

        It 'Emits raw PSCustomObject for HeartBeat with -IncludeHeartbeat' {
            $conn = New-MockYarboConnection
            $hb   = Get-Content (Join-Path $script:fixturesDir 'heart_beat-sample.json') | ConvertFrom-Json
            Push-MockTelemetryEvent -Connection $conn -MessageType 'HeartBeat' -Data $hb

            $script:DefaultConnection = $conn
            $result = Watch-YarboTelemetry -Duration ([TimeSpan]::FromSeconds(2)) -Count 1 -IncludeHeartbeat
            $script:DefaultConnection = $null
            $conn.Dispose()

            $result | Should -Not -BeNullOrEmpty
            $result.working_state | Should -Be 1
        }

        It 'Does not emit HeartBeat when -IncludeHeartbeat is not set' {
            $conn = New-MockYarboConnection
            $hb   = Get-Content (Join-Path $script:fixturesDir 'heart_beat-sample.json') | ConvertFrom-Json
            Push-MockTelemetryEvent -Connection $conn -MessageType 'HeartBeat' -Data $hb

            $script:DefaultConnection = $conn
            $result = Watch-YarboTelemetry -Duration ([TimeSpan]::FromMilliseconds(500)) -Count 1
            $script:DefaultConnection = $null
            $conn.Dispose()

            # No DeviceMSG was queued, so Count=1 never satisfies and result should be empty
            $result | Should -BeNullOrEmpty
        }

        It 'Emits Json string with -OutputFormat Json' {
            $conn = New-MockYarboConnection
            $fixture = Get-Content (Join-Path $script:fixturesDir 'DeviceMSG-sample.json') | ConvertFrom-Json
            Push-MockTelemetryEvent -Connection $conn -MessageType 'DeviceMSG' -Data $fixture

            $script:DefaultConnection = $conn
            $result = Watch-YarboTelemetry -Duration ([TimeSpan]::FromSeconds(2)) -Count 1 -OutputFormat Json
            $script:DefaultConnection = $null
            $conn.Dispose()

            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [string]
            { $result | ConvertFrom-Json } | Should -Not -Throw
        }
    }
}

AfterAll {
    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
}
