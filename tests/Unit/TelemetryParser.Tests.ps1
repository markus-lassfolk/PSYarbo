#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
BeforeAll {
    $scriptRoot = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'
    $fixturesDir = Join-Path $PSScriptRoot '..' 'Fixtures'
    . (Join-Path $scriptRoot 'Classes' 'YarboTelemetry.ps1')
    . (Join-Path $scriptRoot 'Private' 'TelemetryParser.ps1')
}
Describe 'ConvertFrom-GnggaSentence' {
    It 'Returns null coordinates for empty string' {
        $r = ConvertFrom-GnggaSentence -Sentence ''
        $r.Latitude | Should -BeNullOrEmpty
        $r.Longitude | Should -BeNullOrEmpty
        $r.FixQuality | Should -Be 0
    }
    It 'Parses valid GNGGA with fix' {
        $nmea = '$GNGGA,142800.10,5920.05710640,N,01829.82358143,E,4,35,0.5,42.3,M,,,*7B'
        $r = ConvertFrom-GnggaSentence -Sentence $nmea
        $r.FixQuality | Should -Be 4
        $r.Latitude | Should -Not -BeNullOrEmpty
        $r.Longitude | Should -Not -BeNullOrEmpty
    }
}
Describe 'ConvertTo-YarboTelemetry' {
    It 'Maps DeviceMSG fixture to YarboTelemetry' {
        $json = Get-Content (Join-Path $fixturesDir 'DeviceMSG-sample.json') -Raw | ConvertFrom-Json
        $t = ConvertTo-YarboTelemetry -DeviceMsg $json -SerialNumber 'TEST-SN'
        $t | Should -Not -BeNullOrEmpty
        $t.SerialNumber | Should -Be 'TEST-SN'
        $t.BatteryCapacity | Should -Be 83
    }
}
