#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
using module ../../src/PSYarbo/PSYarbo.psd1
<#
.SYNOPSIS
    Unit tests for PSYarbo private helper functions.
#>

BeforeAll {
    $moduleRoot  = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'
    $fixturesDir = Join-Path $PSScriptRoot '..' 'Fixtures'
    $global:privateFunctionsFixturesDir = $fixturesDir

    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
    Import-Module -Name (Join-Path $moduleRoot 'PSYarbo.psd1') -Force -WarningAction SilentlyContinue
}

InModuleScope PSYarbo {
Describe 'ConfigManager' {
    BeforeAll {
        $script:origBroker = $env:YARBO_BROKER
        $script:origSN     = $env:YARBO_SN
        $script:origPort   = $env:YARBO_PORT
        $script:origEmail  = $env:YARBO_EMAIL
    }

    AfterAll {
        # Restore env
        $env:YARBO_BROKER = $script:origBroker
        $env:YARBO_SN     = $script:origSN
        $env:YARBO_PORT   = $script:origPort
        $env:YARBO_EMAIL  = $script:origEmail
    }

    It 'Get-YarboConfig returns default Port 1883 when nothing is set' {
        $env:YARBO_BROKER = $null; $env:YARBO_SN = $null; $env:YARBO_PORT = $null
        $cfg = Get-YarboConfig
        $cfg['Port'] | Should -Be 1883
    }

    It 'Get-YarboConfig resolves Broker from env var' {
        $env:YARBO_BROKER = '10.0.0.1'
        $cfg = Get-YarboConfig
        $cfg['Broker'] | Should -Be '10.0.0.1'
        $env:YARBO_BROKER = $null
    }

    It 'Get-YarboConfig Overrides take priority over env vars' {
        $env:YARBO_BROKER = '10.0.0.1'
        $cfg = Get-YarboConfig -Overrides @{ Broker = '192.168.1.1' }
        $cfg['Broker'] | Should -Be '192.168.1.1'
        $env:YARBO_BROKER = $null
    }

    It 'Test-YarboConfig returns false when Broker and SN are unset' {
        $env:YARBO_BROKER = $null; $env:YARBO_SN = $null
        $result = Test-YarboConfig
        $result | Should -BeFalse
    }

    It 'Test-YarboConfig returns true when Broker and SN are provided via overrides' {
        $result = Test-YarboConfig -Overrides @{ Broker = '192.168.1.1'; SN = 'TEST123' }
        $result | Should -BeTrue
    }
}

Describe 'CredentialHelper' {
    BeforeAll {
        # Use a temp dir for credential files to avoid polluting real store
        $script:origCredFile = $script:YarboCredentialFile
        $script:origCredDir  = $script:YarboCredentialDir
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "PSYarboTestCreds_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        $script:YarboCredentialDir  = $tmpDir
        $script:YarboCredentialFile = Join-Path $tmpDir 'credentials.json'
    }

    AfterAll {
        # Restore
        $script:YarboCredentialFile = $script:origCredFile
        $script:YarboCredentialDir  = $script:origCredDir
    }

    It 'Save-YarboCredential and Get-YarboCredential round-trip (file fallback)' {
        $secret = ConvertTo-SecureString -String 'my-refresh-token-value' -AsPlainText -Force
        Save-YarboCredential -Name 'TestToken' -Value $secret
        $retrieved = Get-YarboCredential -Name 'TestToken'
        $retrieved | Should -Not -BeNull
        $plain = [System.Net.NetworkCredential]::new('', $retrieved).Password
        $plain | Should -Be 'my-refresh-token-value'
    }

    It 'Get-YarboCredential returns null for unknown name' {
        $result = Get-YarboCredential -Name 'NonExistentToken'
        $result | Should -BeNull
    }

    It 'Remove-YarboCredential deletes the stored credential' {
        $secret = ConvertTo-SecureString -String 'to-be-removed' -AsPlainText -Force
        Save-YarboCredential -Name 'TempToken' -Value $secret
        Remove-YarboCredential -Name 'TempToken'
        $result = Get-YarboCredential -Name 'TempToken'
        $result | Should -BeNull
    }
}
}

AfterAll {
    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
}
