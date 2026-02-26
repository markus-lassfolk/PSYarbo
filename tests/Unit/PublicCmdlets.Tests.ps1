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
            $result.GetType().Name | Should -Be 'YarboTelemetry'
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

    Describe 'Remove-YarboSchedule' {
        It 'Is exported from the module' {
            Get-Command -Name 'Remove-YarboSchedule' | Should -Not -BeNullOrEmpty
        }

        It 'Has ShouldProcess support with ConfirmImpact High' {
            $cmd = Get-Command Remove-YarboSchedule
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
            $attr.ConfirmImpact | Should -Be 'High'
        }

        It 'Has mandatory ScheduleId parameter' {
            $cmd = Get-Command Remove-YarboSchedule
            $paramAttr = $cmd.Parameters['ScheduleId'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $paramAttr | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Remove-YarboSchedule
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Synopsis | Should -Not -Be 'Remove-YarboSchedule'
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Set-YarboRobotName' {
        It 'Is exported from the module' {
            Get-Command -Name 'Set-YarboRobotName' | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory SerialNumber and Name parameters' {
            $cmd = Get-Command Set-YarboRobotName
            $snMandatory = $cmd.Parameters['SerialNumber'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $nameMandatory = $cmd.Parameters['Name'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $snMandatory | Should -Not -BeNullOrEmpty
            $nameMandatory | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Set-YarboRobotName
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Add-YarboRobotBinding' {
        It 'Is exported from the module' {
            Get-Command -Name 'Add-YarboRobotBinding' | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory SerialNumber parameter' {
            $cmd = Get-Command Add-YarboRobotBinding
            $mandatoryAttr = $cmd.Parameters['SerialNumber'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNullOrEmpty
        }
    }

    Describe 'Remove-YarboRobotBinding' {
        It 'Is exported from the module' {
            Get-Command -Name 'Remove-YarboRobotBinding' | Should -Not -BeNullOrEmpty
        }

        It 'Has ShouldProcess support with ConfirmImpact High' {
            $cmd = Get-Command Remove-YarboRobotBinding
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
            $attr.ConfirmImpact | Should -Be 'High'
        }

        It 'Has mandatory SerialNumber parameter accepting arrays' {
            $cmd = Get-Command Remove-YarboRobotBinding
            $cmd.Parameters['SerialNumber'].ParameterType | Should -Be ([string[]])
        }
    }

    Describe 'Get-YarboNotificationSetting' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboNotificationSetting' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboNotificationSetting
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboDeviceMessage' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboDeviceMessage' | Should -Not -BeNullOrEmpty
        }

        It 'Has optional SerialNumber parameter for filtering' {
            $cmd = Get-Command Get-YarboDeviceMessage
            $cmd.Parameters.ContainsKey('SerialNumber') | Should -BeTrue
            $mandatoryAttr = $cmd.Parameters['SerialNumber'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -BeNullOrEmpty
        }
    }

    Describe 'YarboTelemetry GPS fields' {
        It 'YarboTelemetry class has Latitude property' {
            $t = [YarboTelemetry]::new()
            $t.PSObject.Properties.Match('Latitude').Count | Should -BeGreaterThan 0
        }

        It 'YarboTelemetry class has Longitude property' {
            $t = [YarboTelemetry]::new()
            $t.PSObject.Properties.Match('Longitude').Count | Should -BeGreaterThan 0
        }

        It 'YarboTelemetry class has Altitude property' {
            $t = [YarboTelemetry]::new()
            $t.PSObject.Properties.Match('Altitude').Count | Should -BeGreaterThan 0
        }

        It 'YarboTelemetry class has FixQuality property' {
            $t = [YarboTelemetry]::new()
            $t.PSObject.Properties.Match('FixQuality').Count | Should -BeGreaterThan 0
        }

        It 'ConvertFrom-GnggaSentence parses a valid GNGGA sentence' {
            $sentence = '$GNGGA,142800.10,5920.05710640,N,01829.82358143,E,4,35,0.5,42.3,M,,,,'
            $result = ConvertFrom-GnggaSentence -Sentence $sentence
            $result.FixQuality | Should -Be 4
            $result.Latitude  | Should -BeGreaterThan 59
            $result.Latitude  | Should -BeLessThan 60
            $result.Longitude | Should -BeGreaterThan 18
            $result.Longitude | Should -BeLessThan 19
            $result.Altitude  | Should -Be 42.3
        }

        It 'ConvertFrom-GnggaSentence returns null coords for fix quality 0' {
            $sentence = '$GNGGA,142800.10,0000.00000,N,00000.00000,E,0,00,,,,'
            $result = ConvertFrom-GnggaSentence -Sentence $sentence
            $result.FixQuality | Should -Be 0
            $result.Latitude  | Should -BeNullOrEmpty
            $result.Longitude | Should -BeNullOrEmpty
        }

        It 'ConvertFrom-GnggaSentence returns default result for non-NMEA input' {
            $result = ConvertFrom-GnggaSentence -Sentence ''
            $result.FixQuality | Should -Be 0
            $result.Latitude  | Should -BeNullOrEmpty
        }

        It 'Watch-YarboTelemetry populates GPS fields from DeviceMSG with GNGGA' {
            $conn = New-MockYarboConnection
            $fixture = Get-Content (Join-Path $script:fixturesDir 'DeviceMSG-sample.json') | ConvertFrom-Json
            Push-MockTelemetryEvent -Connection $conn -MessageType 'DeviceMSG' -Data $fixture

            $script:DefaultConnection = $conn
            $result = Watch-YarboTelemetry -Duration ([TimeSpan]::FromSeconds(2)) -Count 1
            $script:DefaultConnection = $null
            $conn.Dispose()

            # The fixture has a valid GNGGA sentence in rtk_base_data.rover.gngga
            $result | Should -Not -BeNullOrEmpty
            $result.FixQuality | Should -BeGreaterThan 0
            $result.Latitude   | Should -Not -BeNullOrEmpty
            $result.Longitude  | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
}
