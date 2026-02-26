#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules @{ ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.21.0' }
<#
.SYNOPSIS
    Pester tests that run PSScriptAnalyzer against all PowerShell source files.
    Fails if any Error or Warning findings are reported.
#>

BeforeAll {
    $repoRoot     = Join-Path $PSScriptRoot '..'
    $settingsFile = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'

    # Collect all PowerShell source files (exclude test files themselves)
    $script:sourceFiles = Get-ChildItem -Path $repoRoot -Include '*.ps1', '*.psm1', '*.psd1' -Recurse |
        Where-Object { $_.DirectoryName -notmatch '[/\\]tests[/\\]?' } |
        Where-Object { $_.Name -ne 'PSScriptAnalyzerSettings.psd1' }

    # Run PSSA once against all files
    $script:allFindings = @()
    foreach ($file in $script:sourceFiles) {
        $findings = Invoke-ScriptAnalyzer -Path $file.FullName `
            -Settings $settingsFile `
            -Severity @('Error', 'Warning') `
            -ErrorAction SilentlyContinue
        if ($findings) {
            $script:allFindings += $findings
        }
    }
}

Describe 'PSScriptAnalyzer — Source files' {
    Context 'File discovery' {
        It 'Finds at least one PowerShell source file' {
            $script:sourceFiles | Should -Not -BeNullOrEmpty
        }

        It 'Settings file exists' {
            $settingsFile | Should -Exist
        }
    }

    Context 'Analysis results' {
        It 'No Error-severity findings' {
            $errors = $script:allFindings | Where-Object { $_.Severity -eq 'Error' }
            if ($errors) {
                $detail = $errors | ForEach-Object {
                    "  [$($_.Severity)] $($_.RuleName) in $($_.ScriptName):$($_.Line) — $($_.Message)"
                }
                $errors | Should -BeNullOrEmpty -Because (
                    "the following PSSA errors were found:`n" + ($detail -join "`n")
                )
            }
            $errors | Should -BeNullOrEmpty
        }

        It 'No Warning-severity findings' {
            $warnings = $script:allFindings | Where-Object { $_.Severity -eq 'Warning' }
            if ($warnings) {
                $detail = $warnings | ForEach-Object {
                    "  [$($_.Severity)] $($_.RuleName) in $($_.ScriptName):$($_.Line) — $($_.Message)"
                }
                $warnings | Should -BeNullOrEmpty -Because (
                    "the following PSSA warnings were found:`n" + ($detail -join "`n")
                )
            }
            $warnings | Should -BeNullOrEmpty
        }

        It 'Total finding count is zero' {
            $script:allFindings.Count | Should -Be 0
        }
    }
}

# Per-file tests — generated dynamically so each file gets its own It block
Describe 'PSScriptAnalyzer — Per-file' {
    BeforeAll {
        $script:perFileResults = @{}
        foreach ($file in $script:sourceFiles) {
            $findings = Invoke-ScriptAnalyzer -Path $file.FullName `
                -Settings $settingsFile `
                -Severity @('Error', 'Warning') `
                -ErrorAction SilentlyContinue
            $script:perFileResults[$file.Name] = $findings
        }
    }

    foreach ($file in (Get-ChildItem -Path (Join-Path $PSScriptRoot '..') -Include '*.ps1', '*.psm1' -Recurse |
            Where-Object { $_.DirectoryName -notmatch '[/\\]tests[/\\]?' })) {
        It "No findings in $($file.Name)" {
            $findings = $script:perFileResults[$file.Name]
            $findings | Should -BeNullOrEmpty
        }
    }
}
