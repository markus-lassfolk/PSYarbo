#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
BeforeAll {
    $moduleRoot = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'
    $fixturesDir = Join-Path $PSScriptRoot '..' 'Fixtures'
    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
    Import-Module (Join-Path $moduleRoot 'PSYarbo.psd1') -Force -WarningAction SilentlyContinue
    . (Join-Path $PSScriptRoot '..' 'Helpers' 'MockMqttClient.ps1')
}
InModuleScope PSYarbo {
    Describe 'Get-YarboStatus (mocked MQTT)' -Tag Mocked {
        It 'Returns YarboRobot when Send-MqttCommand returns fixture data' {
            $conn = New-MockYarboConnection -SerialNumber 'MOCK-SN' -Broker '192.0.2.1'
            $deviceMsg = Get-Content (Join-Path $fixturesDir 'DeviceMSG-sample.json') -Raw | ConvertFrom-Json
            $feedback = [PSCustomObject]@{ topic = 'get_device_msg'; state = 0; msg = 'success'; data = $deviceMsg }
            Mock Send-MqttCommand -ModuleName PSYarbo -ParameterFilter { $Command -eq 'get_device_msg' } {
                return [YarboCommandResult]::new($feedback)
            }
            $script:DefaultConnection = $conn
            try {
                $status = Get-YarboStatus -Connection $conn
                $status | Should -Not -BeNullOrEmpty
                $status.SerialNumber | Should -Be 'MOCK-SN'
                $status.Battery | Should -Be '83%'
            } finally {
                $script:DefaultConnection = $null
            }
        }
    }
}
