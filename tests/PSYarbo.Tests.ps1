#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Pester test scaffold for the PSYarbo module.
#>

BeforeAll {
    # Resolve module root relative to this test file
    $moduleRoot   = Join-Path $PSScriptRoot '..' 'src' 'PSYarbo'
    $manifestPath = Join-Path $moduleRoot 'PSYarbo.psd1'

    # Remove any previously loaded version to get a clean slate
    if (Get-Module -Name PSYarbo) {
        Remove-Module -Name PSYarbo -Force
    }
}

Describe 'Module manifest' {
    It 'Manifest file exists' {
        $manifestPath | Should -Exist
    }

    It 'Manifest is valid (Test-ModuleManifest)' {
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Has correct ModuleVersion format (semver)' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        $manifest.Version | Should -BeOfType [System.Version]
    }

    It 'Author is set' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        $manifest.Author | Should -Not -BeNullOrEmpty
    }

    It 'Description is set' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        $manifest.Description | Should -Not -BeNullOrEmpty
    }

    It 'PowerShellVersion is 7.0 or higher' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        [version]$manifest.PowerShellVersion | Should -BeGreaterOrEqual ([version]'7.0')
    }

    It 'GUID is set and not empty' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        $manifest.Guid | Should -Not -Be ([Guid]::Empty)
    }
}

Describe 'Module import' {
    It 'Imports without errors' {
        { Import-Module -Name $manifestPath -Force -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Module is loaded after import' {
        Import-Module -Name $manifestPath -Force
        Get-Module -Name PSYarbo | Should -Not -BeNullOrEmpty
    }
}

Describe 'Module structure' {
    BeforeAll {
        Import-Module -Name $manifestPath -Force
        $script:module = Get-Module -Name PSYarbo
    }

    It 'Public directory exists' {
        Join-Path $moduleRoot 'Public' | Should -Exist
    }

    It 'Private directory exists' {
        Join-Path $moduleRoot 'Private' | Should -Exist
    }

    It 'RootModule file exists' {
        Join-Path $moduleRoot 'PSYarbo.psm1' | Should -Exist
    }
}

Describe 'Exported functions' {
    BeforeAll {
        Import-Module -Name $manifestPath -Force
        $script:exported = (Get-Module -Name PSYarbo).ExportedFunctions.Keys
    }

    It 'FunctionsToExport matches actual exported functions' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        $declaredExports = $manifest.ExportedFunctions.Keys

        # Sort both for reliable comparison
        $declared = $declaredExports | Sort-Object
        $actual   = $script:exported | Sort-Object

        $actual | Should -Be $declared
    }

    # Add individual function tests here as functions are implemented, e.g.:
    # It 'Exports Connect-Yarbo' { $script:exported | Should -Contain 'Connect-Yarbo' }
}

AfterAll {
    if (Get-Module -Name PSYarbo) {
        Remove-Module -Name PSYarbo -Force
    }
}
