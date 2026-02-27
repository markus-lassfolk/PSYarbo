#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Integration tests for Get-YarboPlan using mocked MQTT (no real robot).
    Tag: Mocked
#>

BeforeAll {
    $moduleRoot = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'
    $fixturesDir = Join-Path $PSScriptRoot '..' 'Fixtures'
    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
    Import-Module (Join-Path $moduleRoot 'PSYarbo.psd1') -Force -WarningAction SilentlyContinue
    . (Join-Path $PSScriptRoot '..' 'Helpers' 'MockMqttClient.ps1')
}

InModuleScope PSYarbo {
    Describe 'Get-YarboPlan (mocked MQTT)' -Tag Mocked {
        It 'Returns YarboPlan array when Send-MqttCommand returns read_all_plan fixture' {
            $conn = New-MockYarboConnection -SerialNumber 'MOCK-SN'
            $planData = Get-Content (Join-Path $fixturesDir 'data_feedback-samples' 'read_all_plan.json') -Raw | ConvertFrom-Json
            Mock Send-MqttCommand -ModuleName PSYarbo -ParameterFilter { $Command -eq 'read_all_plan' } {
                return [YarboCommandResult]::new([PSCustomObject]@{ topic = 'read_all_plan'; state = 0; msg = 'success'; data = $planData.data })
            }
            $script:DefaultConnection = $conn
            try {
                $plans = Get-YarboPlan -Connection $conn
                $plans | Should -Not -BeNullOrEmpty
                $plans.Count | Should -BeGreaterThan 0
                $plans[0].Name | Should -Not -BeNullOrEmpty
            } finally {
                $script:DefaultConnection = $null
            }
        }
    }
}
