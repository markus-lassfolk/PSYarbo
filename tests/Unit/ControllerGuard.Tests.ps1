#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Unit tests for ControllerGuard (Assert-YarboController).
    Uses Mock Send-MqttCommand when run inside InModuleScope; requires full module load.
#>

BeforeAll {
    $moduleRoot = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'
    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
    Import-Module (Join-Path $moduleRoot 'PSYarbo.psd1') -Force -WarningAction SilentlyContinue
}

InModuleScope PSYarbo {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Helpers' 'MockMqttClient.ps1')
    }
    Describe 'Assert-YarboController' {
        It 'Does nothing when ControllerAcquired is already true' {
            $conn = New-MockYarboConnection -SerialNumber 'GUARD-SN'
            $conn.ControllerAcquired = $true
            { Assert-YarboController -Connection $conn } | Should -Not -Throw
        }

        It 'Sets ControllerAcquired when get_controller returns state 0' {
            $conn = New-MockYarboConnection -SerialNumber 'GUARD-SN'
            $conn.ControllerAcquired = $false
            Mock Send-MqttCommand -ModuleName PSYarbo -Verifiable {
                return [YarboCommandResult]::new([PSCustomObject]@{ topic = 'get_controller'; state = 0; msg = 'success'; data = $null })
            }
            { Assert-YarboController -Connection $conn } | Should -Not -Throw
            $conn.ControllerAcquired | Should -BeTrue
        }
    }
}
