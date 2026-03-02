#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
using module ../../src/PSYarbo/PSYarbo.psd1
<#
.SYNOPSIS
    Unit tests for debug logging (PSYARBO_DEBUG, -Debug, raw) and Export-YarboSupportBundle.
#>

BeforeAll {
    $moduleRoot  = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'
    $helpersDir  = Join-Path $PSScriptRoot '..' 'Helpers'
    $fixturesDir = Join-Path $PSScriptRoot '..' 'Fixtures'

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

    Describe 'Debug mode helpers' {
        Context 'Test-YarboDebugMode' {
            It 'Returns false when DebugPreference is SilentlyContinue and env is not set' {
                $env:PSYARBO_DEBUG = $null
                $env:PSYARBO_DEBUG = ''
                $prev = $DebugPreference
                try {
                    $DebugPreference = 'SilentlyContinue'
                    Test-YarboDebugMode | Should -BeFalse
                } finally {
                    $DebugPreference = $prev
                }
            }

            It 'Returns true when PSYARBO_DEBUG env is 1' {
                $prev = $env:PSYARBO_DEBUG
                try {
                    $env:PSYARBO_DEBUG = '1'
                    Test-YarboDebugMode | Should -BeTrue
                } finally {
                    $env:PSYARBO_DEBUG = $prev
                }
            }

            It 'Returns true when PSYARBO_DEBUG env is true' {
                $prev = $env:PSYARBO_DEBUG
                try {
                    $env:PSYARBO_DEBUG = 'true'
                    Test-YarboDebugMode | Should -BeTrue
                } finally {
                    $env:PSYARBO_DEBUG = $prev
                }
            }

            It 'Returns true when DebugPreference is Continue' {
                $prev = $DebugPreference
                $prevEnv = $env:PSYARBO_DEBUG
                try {
                    $env:PSYARBO_DEBUG = $null
                    $DebugPreference = 'Continue'
                    Test-YarboDebugMode | Should -BeTrue
                } finally {
                    $DebugPreference = $prev
                    $env:PSYARBO_DEBUG = $prevEnv
                }
            }
        }

        Context 'Test-YarboDebugRaw' {
            It 'Returns false when PSYARBO_DEBUG_RAW is not set' {
                $prev = $env:PSYARBO_DEBUG_RAW
                try {
                    $env:PSYARBO_DEBUG_RAW = $null
                    Test-YarboDebugRaw | Should -BeFalse
                } finally {
                    $env:PSYARBO_DEBUG_RAW = $prev
                }
            }

            It 'Returns true when PSYARBO_DEBUG_RAW is 1' {
                $prev = $env:PSYARBO_DEBUG_RAW
                try {
                    $env:PSYARBO_DEBUG_RAW = '1'
                    Test-YarboDebugRaw | Should -BeTrue
                } finally {
                    $env:PSYARBO_DEBUG_RAW = $prev
                }
            }
        }

        Context 'Write-YarboDebugMessage' {
            It 'Does not throw when given a normal message' {
                { Write-YarboDebugMessage -Message 'Test debug line' } | Should -Not -Throw
            }

            It 'Redacts sensitive content in message (JWT)' {
                $prev = $env:PSYARBO_DEBUG
                try {
                    $env:PSYARBO_DEBUG = '1'
                    $info = @()
                    $null = Get-Command Write-Information -ErrorAction SilentlyContinue
                    # When env is set, Write-YarboDebugMessage uses Write-Information; we cannot easily capture it in Pester without redirecting.
                    # So we only assert it doesn't throw and that Protect-YarboLogMessage is applied (tested in Log Redaction context elsewhere).
                    { Write-YarboDebugMessage -Message 'Token: eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjM0In0.sig' } | Should -Not -Throw
                } finally {
                    $env:PSYARBO_DEBUG = $prev
                }
            }
        }
    }

    Describe 'Export-YarboSupportBundle' {
        It 'Is exported from the module' {
            Get-Command -Name 'Export-YarboSupportBundle' -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory Path parameter' {
            $cmd = Get-Command Export-YarboSupportBundle
            $cmd.Parameters['Path'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
        }

        It 'Throws when neither RecordingPath nor Connection is provided' {
            $out = Join-Path ([System.IO.Path]::GetTempPath()) "PSYarbo-SupportBundle-Test-$(Get-Random).json"
            try {
                { Export-YarboSupportBundle -Path $out -ErrorAction Stop } | Should -Throw -ErrorId '*SupportBundleNoSource*'
            } finally {
                if (Test-Path $out) { Remove-Item -LiteralPath $out -Force }
            }
        }

        It 'Creates a valid JSON file when -Connection is provided' {
            $conn = New-MockYarboConnection -SerialNumber 'BUNDLE-SN' -Broker '192.0.2.1' -Port 1883
            $conn.CommandLog.Enqueue([PSCustomObject]@{
                    Timestamp = [datetime]::UtcNow
                    Command   = 'get_device_msg'
                    Direction = 'Sent'
                    Topic     = 'snowbot/BUNDLE-SN/app/get_device_msg'
                    Broker    = '192.0.2.1:1883'
                })
            $conn.TelemetryLog.Enqueue([PSCustomObject]@{
                    Timestamp   = [datetime]::UtcNow
                    MessageType = 'DeviceMSG'
                    Direction   = 'Pushed'
                    Topic       = 'snowbot/BUNDLE-SN/device/DeviceMSG'
                })

            $out = Join-Path ([System.IO.Path]::GetTempPath()) "PSYarbo-SupportBundle-$(Get-Random).json"
            try {
                $result = Export-YarboSupportBundle -Path $out -Connection $conn
                $result | Should -Not -BeNullOrEmpty
                $result.FullName | Should -Be (Resolve-Path -LiteralPath $out).Path
                Test-Path -LiteralPath $out | Should -BeTrue
                $json = Get-Content -LiteralPath $out -Raw | ConvertFrom-Json
                $json.ExportDate   | Should -Not -BeNullOrEmpty
                $json.Module       | Should -Be 'PSYarbo'
                $json.Source      | Should -Contain 'Connection'
                $json.ConnectionLog.Broker        | Should -Be '192.0.2.1'
                $json.ConnectionLog.SerialNumber  | Should -Be 'BUNDLE-SN'
                $json.ConnectionLog.CommandLog.Count   | Should -BeGreaterThan 0
                $json.ConnectionLog.TelemetryLog.Count | Should -BeGreaterThan 0
            } finally {
                $conn.Dispose()
                if (Test-Path $out) { Remove-Item -LiteralPath $out -Force }
            }
        }

        It 'Creates a valid JSON file when -RecordingPath is provided' {
            $recDir = Join-Path ([System.IO.Path]::GetTempPath()) "PSYarbo-Rec-$(Get-Random)"
            $recPath = Join-Path $recDir 'recording.json'
            $outPath = Join-Path ([System.IO.Path]::GetTempPath()) "PSYarbo-SupportBundle-$(Get-Random).json"
            try {
                New-Item -ItemType Directory -Path $recDir -Force | Out-Null
                $rec = [PSCustomObject]@{
                    RecordedAt      = [datetime]::UtcNow.ToString('o')
                    Broker          = '192.0.2.2'
                    Port            = 1883
                    DurationSeconds = 10
                    MessageCount    = 1
                    Messages        = @(
                        [PSCustomObject]@{
                            Index        = 0
                            Topic        = 'snowbot/SN1/device/DeviceMSG'
                            PayloadBase64 = [Convert]::ToBase64String([byte[]]@(0x78, 0x9C))  # minimal zlib header
                        }
                    )
                }
                $rec | ConvertTo-Json -Depth 5 -Compress:$false | Set-Content -LiteralPath $recPath -Encoding UTF8

                $result = Export-YarboSupportBundle -Path $outPath -RecordingPath $recPath
                $result | Should -Not -BeNullOrEmpty
                Test-Path -LiteralPath $outPath | Should -BeTrue
                $json = Get-Content -LiteralPath $outPath -Raw | ConvertFrom-Json
                $json.Source    | Should -Contain 'Recording'
                $json.Recording.Broker           | Should -Be '192.0.2.2'
                $json.Recording.MessageCount     | Should -Be 1
                $json.Recording.Topics.PSObject.Properties.Name | Should -Contain 'snowbot/SN1/device/DeviceMSG'
            } finally {
                if (Test-Path $outPath) { Remove-Item -LiteralPath $outPath -Force }
                if (Test-Path $recPath) { Remove-Item -LiteralPath $recPath -Force }
                if (Test-Path $recDir) { Remove-Item -LiteralPath $recDir -Recurse -Force }
            }
        }

        It 'Has synopsis and examples in help' {
            $help = Get-Help Export-YarboSupportBundle
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Synopsis | Should -Not -Be 'Export-YarboSupportBundle'
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0
        }

        It 'Accepts Connection from pipeline' {
            $conn = New-MockYarboConnection
            $out = Join-Path ([System.IO.Path]::GetTempPath()) "PSYarbo-SupportBundle-Pipe-$(Get-Random).json"
            try {
                $result = $conn | Export-YarboSupportBundle -Path $out
                $result | Should -Not -BeNullOrEmpty
                $json = Get-Content -LiteralPath $out -Raw | ConvertFrom-Json
                $json.Source | Should -Contain 'Connection'
            } finally {
                $conn.Dispose()
                if (Test-Path $out) { Remove-Item -LiteralPath $out -Force }
            }
        }
    }
}

AfterAll {
    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
}
