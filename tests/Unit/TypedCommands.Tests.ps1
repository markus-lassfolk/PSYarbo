#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
using module ../../src/PSYarbo/PSYarbo.psd1
<#
.SYNOPSIS
    Unit tests for the ~30 typed command cmdlets added in issue #30.
#>

BeforeAll {
    $moduleRoot = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'

    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
    Import-Module -Name (Join-Path $moduleRoot 'PSYarbo.psd1') -Force -WarningAction SilentlyContinue

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
    }

    # ─── Robot Control ─────────────────────────────────────────────────────────

    Describe 'Stop-YarboEmergency' {
        It 'Is exported from the module' {
            Get-Command -Name 'Stop-YarboEmergency' | Should -Not -BeNullOrEmpty
        }

        It 'Has ConfirmImpact High' {
            $cmd = Get-Command Stop-YarboEmergency
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }

        It 'Has ShouldProcess support' {
            $cmd = Get-Command Stop-YarboEmergency
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Stop-YarboEmergency
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Synopsis | Should -Not -Be 'Stop-YarboEmergency'
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Unlock-YarboEmergency' {
        It 'Is exported from the module' {
            Get-Command -Name 'Unlock-YarboEmergency' | Should -Not -BeNullOrEmpty
        }

        It 'Has ShouldProcess support' {
            $cmd = Get-Command Unlock-YarboEmergency
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Unlock-YarboEmergency
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Stop-Yarbo' {
        It 'Is exported from the module' {
            Get-Command -Name 'Stop-Yarbo' | Should -Not -BeNullOrEmpty
        }

        It 'Has ShouldProcess support' {
            $cmd = Get-Command Stop-Yarbo
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Stop-Yarbo
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Restart-YarboContainer' {
        It 'Is exported from the module' {
            Get-Command -Name 'Restart-YarboContainer' | Should -Not -BeNullOrEmpty
        }

        It 'Has ConfirmImpact High' {
            $cmd = Get-Command Restart-YarboContainer
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Restart-YarboContainer
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Stop-YarboShutdown' {
        It 'Is exported from the module' {
            Get-Command -Name 'Stop-YarboShutdown' | Should -Not -BeNullOrEmpty
        }

        It 'Has ConfirmImpact High' {
            $cmd = Get-Command Stop-YarboShutdown
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Stop-YarboShutdown
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Start-YarboRecharge' {
        It 'Is exported from the module' {
            Get-Command -Name 'Start-YarboRecharge' | Should -Not -BeNullOrEmpty
        }

        It 'Has ShouldProcess support' {
            $cmd = Get-Command Start-YarboRecharge
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Start-YarboRecharge
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    # ─── Lights & Sound ────────────────────────────────────────────────────────

    Describe 'Set-YarboHeadLight' {
        It 'Is exported from the module' {
            Get-Command -Name 'Set-YarboHeadLight' | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory Enabled parameter of type bool' {
            $cmd = Get-Command Set-YarboHeadLight
            $cmd.Parameters.ContainsKey('Enabled') | Should -BeTrue
            $cmd.Parameters['Enabled'].ParameterType | Should -Be ([bool])
            $mandatoryAttr = $cmd.Parameters['Enabled'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Set-YarboHeadLight
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Set-YarboRoofLights' {
        It 'Is exported from the module' {
            Get-Command -Name 'Set-YarboRoofLights' | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory Enabled parameter' {
            $cmd = Get-Command Set-YarboRoofLights
            $mandatoryAttr = $cmd.Parameters['Enabled'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Set-YarboRoofLights
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Set-YarboLaser' {
        It 'Is exported from the module' {
            Get-Command -Name 'Set-YarboLaser' | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory Enabled parameter' {
            $cmd = Get-Command Set-YarboLaser
            $mandatoryAttr = $cmd.Parameters['Enabled'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Set-YarboLaser
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Set-YarboSound' {
        It 'Is exported from the module' {
            Get-Command -Name 'Set-YarboSound' | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory Volume parameter of type int' {
            $cmd = Get-Command Set-YarboSound
            $cmd.Parameters.ContainsKey('Volume') | Should -BeTrue
            $cmd.Parameters['Volume'].ParameterType | Should -Be ([int])
            $mandatoryAttr = $cmd.Parameters['Volume'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNullOrEmpty
        }

        It 'Volume has ValidateRange 0-10' {
            $cmd = Get-Command Set-YarboSound
            $validateRange = $cmd.Parameters['Volume'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange | Should -Not -BeNullOrEmpty
            $validateRange.MinRange | Should -Be 0
            $validateRange.MaxRange | Should -Be 10
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Set-YarboSound
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Start-YarboSong' {
        It 'Is exported from the module' {
            Get-Command -Name 'Start-YarboSong' | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory SongId parameter of type int' {
            $cmd = Get-Command Start-YarboSong
            $cmd.Parameters.ContainsKey('SongId') | Should -BeTrue
            $cmd.Parameters['SongId'].ParameterType | Should -Be ([int])
            $mandatoryAttr = $cmd.Parameters['SongId'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Start-YarboSong
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    # ─── Camera & Detection ────────────────────────────────────────────────────

    Describe 'Set-YarboCamera' {
        It 'Is exported from the module' {
            Get-Command -Name 'Set-YarboCamera' | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory Enabled parameter of type bool' {
            $cmd = Get-Command Set-YarboCamera
            $cmd.Parameters['Enabled'].ParameterType | Should -Be ([bool])
            $mandatoryAttr = $cmd.Parameters['Enabled'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Set-YarboCamera
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Set-YarboPersonDetect' {
        It 'Is exported from the module' {
            Get-Command -Name 'Set-YarboPersonDetect' | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory Enabled parameter' {
            $cmd = Get-Command Set-YarboPersonDetect
            $mandatoryAttr = $cmd.Parameters['Enabled'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Set-YarboPersonDetect
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Set-YarboUSB' {
        It 'Is exported from the module' {
            Get-Command -Name 'Set-YarboUSB' | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory Enabled parameter of type bool' {
            $cmd = Get-Command Set-YarboUSB
            $cmd.Parameters['Enabled'].ParameterType | Should -Be ([bool])
            $mandatoryAttr = $cmd.Parameters['Enabled'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Set-YarboUSB
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    # ─── Plans & Scheduling ────────────────────────────────────────────────────

    Describe 'Get-YarboAllPlans' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboAllPlans' | Should -Not -BeNullOrEmpty
        }

        It 'Does not require mandatory parameters' {
            $cmd = Get-Command Get-YarboAllPlans
            $mandatoryParams = $cmd.Parameters.Values | Where-Object {
                $_.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            }
            $mandatoryParams | Should -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboAllPlans
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Remove-YarboAllPlans' {
        It 'Is exported from the module' {
            Get-Command -Name 'Remove-YarboAllPlans' | Should -Not -BeNullOrEmpty
        }

        It 'Has ConfirmImpact High' {
            $cmd = Get-Command Remove-YarboAllPlans
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High'
        }

        It 'Has ShouldProcess support' {
            $cmd = Get-Command Remove-YarboAllPlans
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Remove-YarboAllPlans
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Invoke-YarboPlanAction' {
        It 'Is exported from the module' {
            Get-Command -Name 'Invoke-YarboPlanAction' | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory Action parameter of type string' {
            $cmd = Get-Command Invoke-YarboPlanAction
            $cmd.Parameters.ContainsKey('Action') | Should -BeTrue
            $cmd.Parameters['Action'].ParameterType | Should -Be ([string])
            $mandatoryAttr = $cmd.Parameters['Action'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Invoke-YarboPlanAction
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboSchedules' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboSchedules' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboSchedules
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    # ─── Navigation & Maps ─────────────────────────────────────────────────────

    Describe 'Start-YarboWaypoint' {
        It 'Is exported from the module' {
            Get-Command -Name 'Start-YarboWaypoint' | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory Index parameter of type int' {
            $cmd = Get-Command Start-YarboWaypoint
            $cmd.Parameters.ContainsKey('Index') | Should -BeTrue
            $cmd.Parameters['Index'].ParameterType | Should -Be ([int])
            $mandatoryAttr = $cmd.Parameters['Index'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Start-YarboWaypoint
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboRechargePoint' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboRechargePoint' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboRechargePoint
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Save-YarboChargingPoint' {
        It 'Is exported from the module' {
            Get-Command -Name 'Save-YarboChargingPoint' | Should -Not -BeNullOrEmpty
        }

        It 'Has ShouldProcess support' {
            $cmd = Get-Command Save-YarboChargingPoint
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Save-YarboChargingPoint
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboCleanArea' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboCleanArea' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboCleanArea
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboMapBackup' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboMapBackup' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboMapBackup
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Save-YarboMapBackup' {
        It 'Is exported from the module' {
            Get-Command -Name 'Save-YarboMapBackup' | Should -Not -BeNullOrEmpty
        }

        It 'Has ShouldProcess support' {
            $cmd = Get-Command Save-YarboMapBackup
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Save-YarboMapBackup
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    # ─── WiFi & Connectivity ───────────────────────────────────────────────────

    Describe 'Get-YarboWifiList' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboWifiList' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboWifiList
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboConnectedWifi' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboConnectedWifi' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboConnectedWifi
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Start-YarboHotspot' {
        It 'Is exported from the module' {
            Get-Command -Name 'Start-YarboHotspot' | Should -Not -BeNullOrEmpty
        }

        It 'Has ShouldProcess support' {
            $cmd = Get-Command Start-YarboHotspot
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.SupportsShouldProcess | Should -BeTrue
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Start-YarboHotspot
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboHubInfo' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboHubInfo' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboHubInfo
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    # ─── Diagnostics ───────────────────────────────────────────────────────────

    Describe 'Get-YarboBatteryCellTemps' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboBatteryCellTemps' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboBatteryCellTemps
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboMotorTemps' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboMotorTemps' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboMotorTemps
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboBodyCurrent' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboBodyCurrent' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboBodyCurrent
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboHeadCurrent' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboHeadCurrent' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboHeadCurrent
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboSpeed' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboSpeed' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboSpeed
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboOdometer' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboOdometer' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboOdometer
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboProductCode' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboProductCode' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboProductCode
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }

    Describe 'Get-YarboNoChargePeriod' {
        It 'Is exported from the module' {
            Get-Command -Name 'Get-YarboNoChargePeriod' | Should -Not -BeNullOrEmpty
        }

        It 'Has synopsis and example in help' {
            $help = Get-Help Get-YarboNoChargePeriod
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }
    }
}

AfterAll {
    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
}
