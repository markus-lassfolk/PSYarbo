#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Unit tests for Zlib payload compression (Private/ZlibCodec.ps1).
#>

BeforeAll {
    $scriptRoot = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'
    . (Join-Path $scriptRoot 'Private' 'ZlibCodec.ps1')
}

Describe 'ConvertTo-ZlibPayload' {
    It 'Compresses a simple hashtable to non-empty bytes' {
        $payload = @{ foo = 'bar' }
        $bytes = ConvertTo-ZlibPayload -Payload $payload
        $bytes | Should -Not -BeNullOrEmpty
        $bytes -is [byte[]] | Should -BeTrue
        $bytes.Length | Should -BeGreaterThan 0
    }

    It 'Round-trips with ConvertFrom-ZlibPayload' {
        $payload = @{ cmd = 'get_controller'; id = 1 }
        $bytes = ConvertTo-ZlibPayload -Payload $payload
        $decoded = ConvertFrom-ZlibPayload -Data $bytes
        $decoded | Should -Not -BeNullOrEmpty
        $decoded.cmd | Should -Be 'get_controller'
        $decoded.id | Should -Be 1
    }
}

Describe 'ConvertFrom-ZlibPayload' {
    It 'Returns null for empty byte array' {
        $result = ConvertFrom-ZlibPayload -Data @()
        $result | Should -BeNullOrEmpty
    }

    It 'Decompresses valid zlib bytes from round-trip' {
        $original = @{ topic = 'read_schedules'; state = 0 }
        $bytes = ConvertTo-ZlibPayload -Payload $original
        $decoded = ConvertFrom-ZlibPayload -Data $bytes
        $decoded.topic | Should -Be 'read_schedules'
        $decoded.state | Should -Be 0
    }
}
