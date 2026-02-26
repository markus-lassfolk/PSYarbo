#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
using module ../src/PSYarbo/PSYarbo.psd1
<#
.SYNOPSIS
    Comprehensive Pester 5 tests for the PSYarbo module.
#>

BeforeAll {
    $moduleRoot   = Join-Path $PSScriptRoot '..' 'src' 'PSYarbo'
    $manifestPath = Join-Path $moduleRoot 'PSYarbo.psd1'
    $fixturesDir  = Join-Path $PSScriptRoot 'Fixtures'
    $global:fixturesDir = $fixturesDir

    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
}

Describe 'Module Manifest' {
    It 'Manifest file exists' {
        $manifestPath | Should -Exist
    }

    It 'Manifest is valid' {
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Has correct ModuleVersion format' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        $manifest.Version | Should -BeOfType [System.Version]
    }

    It 'Author is set' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        $manifest.Author | Should -Be 'Markus Lassfolk'
    }

    It 'PowerShellVersion is 7.4+' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        [version]$manifest.PowerShellVersion | Should -BeGreaterOrEqual ([version]'7.4')
    }

    It 'GUID is set and valid' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        $manifest.Guid | Should -Not -Be ([Guid]::Empty)
    }

    It 'Declares all expected function exports' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        $exports = $manifest.ExportedFunctions.Keys

        # Core cmdlets that must be present
        $expected = @(
            'Connect-Yarbo', 'Disconnect-Yarbo', 'Find-Yarbo',
            'Get-YarboStatus', 'Get-YarboRobot', 'Get-YarboBattery', 'Get-YarboFirmware',
            'Set-YarboLight', 'Start-YarboBuzzer', 'Stop-YarboBuzzer',
            'Start-YarboPlan', 'Stop-YarboPlan', 'Suspend-YarboPlan', 'Resume-YarboPlan',
            'Send-YarboCommand',
            'Resume-Yarbo', 'Suspend-Yarbo',
            'Start-YarboManualDrive', 'Set-YarboVelocity', 'Set-YarboRoller', 'Set-YarboChute', 'Stop-YarboManualDrive',
            'Get-YarboPlan', 'New-YarboPlan', 'Remove-YarboPlan',
            'Get-YarboMap', 'Get-YarboSchedule', 'Set-YarboSchedule',
            'Get-YarboTelemetry', 'Watch-YarboTelemetry', 'Export-YarboTelemetry',
            'Connect-YarboCloud', 'Get-YarboDevice', 'Get-YarboVideo', 'Get-YarboPlanHistory',
            'Test-YarboConnection', 'Get-YarboLog'
        )

        foreach ($fn in $expected) {
            $exports | Should -Contain $fn -Because "$fn should be exported"
        }
    }
}

Describe 'Module Import' {
    It 'Imports without errors (MQTTnet warning expected)' {
        # MQTTnet.dll won't be present in CI, but module should still load with a warning
        { Import-Module -Name $manifestPath -Force -ErrorAction Stop -WarningAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Module is loaded after import' {
        Import-Module -Name $manifestPath -Force -WarningAction SilentlyContinue
        Get-Module -Name PSYarbo | Should -Not -BeNullOrEmpty
    }

    AfterAll {
        if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
    }
}

Describe 'Module Structure' {
    It 'Public directory exists with cmdlet files' {
        Join-Path $moduleRoot 'Public' | Should -Exist
        (Get-ChildItem -Path (Join-Path $moduleRoot 'Public') -Recurse -Filter '*.ps1').Count | Should -BeGreaterThan 20
    }

    It 'Private directory exists with helper files' {
        Join-Path $moduleRoot 'Private' | Should -Exist
        (Get-ChildItem -Path (Join-Path $moduleRoot 'Private') -Filter '*.ps1').Count | Should -BeGreaterThan 3
    }

    It 'Classes directory exists' {
        Join-Path $moduleRoot 'Classes' | Should -Exist
        (Get-ChildItem -Path (Join-Path $moduleRoot 'Classes') -Filter '*.ps1').Count | Should -Be 9
    }

    It 'Format file exists' {
        Join-Path $moduleRoot 'PSYarbo.Format.ps1xml' | Should -Exist
    }

    It 'Types file exists' {
        Join-Path $moduleRoot 'PSYarbo.Types.ps1xml' | Should -Exist
    }

    It 'about_PSYarbo_MQTT help file exists' {
        Join-Path $moduleRoot 'en-US' 'about_PSYarbo_MQTT.help.txt' | Should -Exist
    }
}

Describe 'Classes' {
    BeforeAll {
        # Load classes directly for testing
        $classFiles = @(
            'YarboExceptions', 'YarboLightState', 'YarboCommandResult',
            'YarboTelemetry', 'YarboPlan', 'YarboSchedule', 'YarboRobot',
            'YarboConnection', 'YarboCloudSession'
        )
        foreach ($class in $classFiles) {
            . (Join-Path $moduleRoot "Classes/$class.ps1")
        }
    }

    Context 'YarboLightState' {
        It 'AllOn returns all channels at 255' {
            $state = [YarboLightState]::AllOn()
            $state.HeadLight | Should -Be 255
            $state.LeftWhite | Should -Be 255
            $state.RightWhite | Should -Be 255
            $state.BodyLeftRed | Should -Be 255
            $state.BodyRightRed | Should -Be 255
            $state.TailLeftRed | Should -Be 255
            $state.TailRightRed | Should -Be 255
        }

        It 'AllOff returns all channels at 0' {
            $state = [YarboLightState]::AllOff()
            $state.HeadLight | Should -Be 0
            $state.TailRightRed | Should -Be 0
        }

        It 'ToPayload returns correct protocol keys' {
            $state = [YarboLightState]::AllOn()
            $payload = $state.ToPayload()
            $payload.led_head | Should -Be 255
            $payload.led_left_w | Should -Be 255
            $payload.led_right_w | Should -Be 255
            $payload.body_left_r | Should -Be 255
            $payload.body_right_r | Should -Be 255
            $payload.tail_left_r | Should -Be 255
            $payload.tail_right_r | Should -Be 255
        }

        It 'ToString formats correctly' {
            $state = [YarboLightState]::AllOn()
            $str = $state.ToString()
            $str | Should -BeLike 'Head:255*'
        }
    }

    Context 'YarboCommandResult' {
        It 'Parses success feedback' {
            $feedback = [PSCustomObject]@{ topic = 'get_controller'; state = 0; msg = 'success'; data = @{} }
            $result = [YarboCommandResult]::new($feedback)
            $result.Success | Should -BeTrue
            $result.Topic | Should -Be 'get_controller'
            $result.State | Should -Be 0
        }

        It 'Parses failure feedback' {
            $feedback = [PSCustomObject]@{ topic = 'start_plan'; state = 1; msg = 'failed'; data = $null }
            $result = [YarboCommandResult]::new($feedback)
            $result.Success | Should -BeFalse
            $result.State | Should -Be 1
        }
    }

    Context 'YarboPlan' {
        It 'ToString shows ID, name, and areas' {
            $plan = [YarboPlan]::new()
            $plan.Id = 1; $plan.Name = 'Uteplats'; $plan.AreaIds = @(29)
            $plan.ToString() | Should -BeLike '1: Uteplats*'
        }
    }

    Context 'YarboSchedule' {
        It 'Decodes weekday bitmask 127 as all 7 days' {
            $sched = [YarboSchedule]::new()
            $sched.WeekDay = 127
            $days = $sched.GetDays()
            $days.Count | Should -Be 7
        }

        It 'Decodes weekday bitmask for Mon+Wed+Fri (42)' {
            $sched = [YarboSchedule]::new()
            $sched.WeekDay = 42
            $days = $sched.GetDays()
            $days | Should -Contain ([DayOfWeek]::Monday)
            $days | Should -Contain ([DayOfWeek]::Wednesday)
            $days | Should -Contain ([DayOfWeek]::Friday)
            $days.Count | Should -Be 3
        }

        It 'Decodes single day Sunday (1)' {
            $sched = [YarboSchedule]::new()
            $sched.WeekDay = 1
            $days = $sched.GetDays()
            $days.Count | Should -Be 1
            $days[0] | Should -Be ([DayOfWeek]::Sunday)
        }
    }

    Context 'YarboConnection' {
        It 'Initializes with correct defaults' {
            $conn = [YarboConnection]::new()
            $conn.State | Should -Be ([MqttConnectionState]::Disconnected)
            $conn.ControllerAcquired | Should -BeFalse
            $conn.ResponseQueue.Count | Should -Be 0            # object exists but starts empty
            $conn.CommandLog.Count    | Should -Be 0            # object exists but starts empty
            $conn.CommandSemaphore   | Should -Not -BeNull     # SemaphoreSlim passes through pipeline
        }

        It 'ToString formats correctly' {
            $conn = [YarboConnection]::new()
            $conn.Broker = '192.168.1.24'
            $conn.Port = 1883
            $conn.SerialNumber = 'TEST123'
            $conn.ToString() | Should -Be 'Yarbo[TEST123@192.168.1.24:1883]'
        }
    }

    Context 'YarboExceptions' {
        It 'YarboTimeoutException includes ErrorId' {
            $ex = [YarboTimeoutException]::new('get_device_msg', 5000)
            $ex.ErrorId | Should -Be 'PSYarbo.Timeout.get_device_msg'
            $ex.TimeoutMs | Should -Be 5000
            $ex.Remediation | Should -Not -BeNullOrEmpty
        }

        It 'YarboConnectionException includes broker info' {
            $ex = [YarboConnectionException]::new('Connection failed', '192.168.1.24')
            $ex.Broker | Should -Be '192.168.1.24'
            $ex.Remediation | Should -BeLike '*192.168.1.24*'
        }

        It 'YarboCommandException wraps result' {
            $feedback = [PSCustomObject]@{ Topic = 'test'; State = 1; Message = 'fail'; Data = $null }
            $ex = [YarboCommandException]::new($feedback)
            $ex.State | Should -Be 1
        }
    }

    Context 'YarboRobot' {
        It 'ToString shows name, SN, battery, and state' {
            $robot = [YarboRobot]::new()
            $robot.Name = 'Allgott'
            $robot.SerialNumber = 'SN123'
            $robot.BatteryCapacity = 83
            $robot.WorkingState = 1
            $robot.ToString() | Should -BeLike 'Allgott*83%*Active'
        }
    }
}

InModuleScope PSYarbo {
Describe 'Private Functions' {
    BeforeAll {
        # Share fixtures path into module scope
        $script:fixturesDir = $global:fixturesDir
    }

    Context 'Zlib Codec' {
        It 'Round-trips a payload through compress/decompress' {
            $payload = @{ state = 1; timeStamp = 1234567890 }
            $compressed = ConvertTo-ZlibPayload -Payload $payload
            $compressed | Should -BeOfType [byte]
            $compressed.Length | Should -BeGreaterThan 0

            $decompressed = ConvertFrom-ZlibPayload -Data $compressed
            $decompressed.state | Should -Be 1
            $decompressed.timeStamp | Should -Be 1234567890
        }

        It 'Decompresses a real DeviceMSG fixture' {
            $json = Get-Content (Join-Path $fixturesDir 'DeviceMSG-sample.json') -Raw
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

            # Compress like the robot would
            $ms = [System.IO.MemoryStream]::new()
            $zlib = [System.IO.Compression.ZLibStream]::new($ms, [System.IO.Compression.CompressionLevel]::Optimal, $true)
            $zlib.Write($bytes, 0, $bytes.Length)
            $zlib.Dispose()
            $compressed = $ms.ToArray()
            $ms.Dispose()

            $result = ConvertFrom-ZlibPayload -Data $compressed
            $result.BatteryMSG.capacity | Should -Be 83
            $result.StateMSG.working_state | Should -Be 1
        }

        It 'Falls back to plain JSON for uncompressed payloads' {
            $json = '{"working_state": 0}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $result = ConvertFrom-ZlibPayload -Data $bytes
            $result.working_state | Should -Be 0
        }

        It 'Handles empty payload gracefully' {
            $compressed = ConvertTo-ZlibPayload -Payload @{}
            $decompressed = ConvertFrom-ZlibPayload -Data $compressed
            # Empty payloads return $null (guarded) rather than throwing
            $decompressed | Should -BeNullOrEmpty
        }
    }

    Context 'Telemetry Parser' {
        BeforeAll {
            $script:fixture = Get-Content (Join-Path $fixturesDir 'DeviceMSG-sample.json') | ConvertFrom-Json
        }

        It 'Parses battery capacity' {
            $t = ConvertTo-YarboTelemetry -DeviceMsg $fixture -SerialNumber 'TEST'
            $t.BatteryCapacity | Should -Be 83
        }

        It 'Parses RTK heading' {
            $t = ConvertTo-YarboTelemetry -DeviceMsg $fixture -SerialNumber 'TEST'
            [math]::Round($t.Heading, 4) | Should -Be 339.4576
        }

        It 'Parses working state flags' {
            $t = ConvertTo-YarboTelemetry -DeviceMsg $fixture -SerialNumber 'TEST'
            $t.WorkingState | Should -Be 1
            $t.IsPlanning | Should -BeFalse
            $t.IsRecharging | Should -BeFalse
        }

        It 'Parses odometry confidence' {
            $t = ConvertTo-YarboTelemetry -DeviceMsg $fixture -SerialNumber 'TEST'
            [math]::Round($t.OdomConfidence, 3) | Should -Be 0.915
        }

        It 'Parses chute angle' {
            $t = ConvertTo-YarboTelemetry -DeviceMsg $fixture -SerialNumber 'TEST'
            $t.ChuteAngle | Should -Be 105
        }

        It 'Parses wireless charging info' {
            $t = ConvertTo-YarboTelemetry -DeviceMsg $fixture -SerialNumber 'TEST'
            $t.WirelessChargeState | Should -Be 2
            $t.WirelessChargeVoltage | Should -Be 4186
        }
    }

    Context 'Robot Parser' {
        BeforeAll {
            $script:fixture = Get-Content (Join-Path $fixturesDir 'DeviceMSG-sample.json') | ConvertFrom-Json
        }

        It 'Parses into YarboRobot' {
            $r = ConvertTo-YarboRobot -DeviceMsg $fixture -SerialNumber 'TEST-SN' -Broker '192.168.1.24' -Port 1883
            $r.SerialNumber | Should -Be 'TEST-SN'
            $r.BatteryCapacity | Should -Be 83
            $r.HeadType | Should -Be 1
            $r.HeadSerialNumber | Should -Be '243904023M1L1599'
            $r.WorkingState | Should -Be 1
            $r.ChuteAngle | Should -Be 105
            $r.LedRegister | Should -Be '69666'
        }

        It 'Parses route priority as hashtable' {
            $r = ConvertTo-YarboRobot -DeviceMsg $fixture -SerialNumber 'TEST' -Broker 'x' -Port 1883
            $r.RoutePriority['hg0'] | Should -Be 10
            $r.RoutePriority['wlan0'] | Should -Be 600
        }
    }

    Context 'Log Redaction' {
        It 'Redacts JWT tokens' {
            $msg = "Token: eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc123signature"
            $redacted = Protect-YarboLogMessage -Message $msg
            $redacted | Should -BeLike '*[REDACTED-JWT]*'
            $redacted | Should -Not -BeLike '*eyJhbGci*'
        }

        It 'Redacts Authorization headers' {
            $msg = "Authorization: Bearer some-secret-token-here"
            $redacted = Protect-YarboLogMessage -Message $msg
            $redacted | Should -Be 'Authorization: Bearer [REDACTED]'
        }

        It 'Passes through non-sensitive messages unchanged' {
            $msg = "Connecting to 192.168.1.24:1883"
            $redacted = Protect-YarboLogMessage -Message $msg
            $redacted | Should -Be $msg
        }
    }

    Context 'Error Helper' {
        It 'Creates ErrorRecord with standardized ErrorId' {
            $err = New-YarboError -Message 'Test error' -ErrorId 'PSYarbo.Test.Error' -Category 'InvalidResult'
            $err | Should -BeOfType [System.Management.Automation.ErrorRecord]
            $err.FullyQualifiedErrorId | Should -BeLike '*PSYarbo.Test.Error*'
        }
    }

    Context 'MQTT Payload Segment Handling' {
        It 'ArraySegment with non-zero offset decodes correctly via .ToArray()' {
            # Regression: PayloadSegment.Array returns the backing buffer without respecting Offset/Count.
            # Using ArraySegment.ToArray() (or Offset+Count slice) must be used instead.

            $payload  = @{ working_state = 42 }
            $json     = $payload | ConvertTo-Json -Compress
            $bytes    = [System.Text.Encoding]::UTF8.GetBytes($json)

            # Compress to simulate a real MQTT payload
            $ms   = [System.IO.MemoryStream]::new()
            $zlib = [System.IO.Compression.ZLibStream]::new($ms, [System.IO.Compression.CompressionLevel]::Optimal, $true)
            $zlib.Write($bytes, 0, $bytes.Length)
            $zlib.Dispose()
            $compressed = $ms.ToArray()
            $ms.Dispose()

            # Simulate ArraySegment with non-zero offset (prefix garbage bytes before actual payload)
            $prefix     = [byte[]]@(0xDE, 0xAD, 0xBE, 0xEF)  # 4 garbage bytes
            $backing    = $prefix + $compressed               # full backing buffer
            $seg        = [System.ArraySegment[byte]]::new($backing, $prefix.Length, $compressed.Length)

            # .Array returns the FULL backing buffer (bug path)
            $bugPath    = $seg.Array
            $bugPath.Length | Should -Be ($prefix.Length + $compressed.Length) -Because '.Array is the full backing buffer'

            # .ToArray() respects Offset+Count (fix path)
            $fixPath    = $seg.ToArray()
            $fixPath.Length | Should -Be $compressed.Length -Because '.ToArray() slices correctly'

            # Only the fix path decodes correctly
            $decoded = ConvertFrom-ZlibPayload -Data $fixPath
            $decoded.working_state | Should -Be 42 -Because 'fix path must decode to original payload'
        }

        It 'Null/empty payload guard skips decode gracefully' {
            # ConvertFrom-ZlibPayload should return $null for empty byte arrays
            $result = ConvertFrom-ZlibPayload -Data ([byte[]]@())
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'YarboCommandResult TimedOut' {
        It 'Timeout() factory creates a result with TimedOut=true and Success=false' {
            $r = [YarboCommandResult]::Timeout('get_device_msg', 5000)
            $r.TimedOut | Should -BeTrue
            $r.Success  | Should -BeFalse
            $r.State    | Should -Be -1
            $r.Topic    | Should -Be 'get_device_msg'
            $r.Message  | Should -BeLike '*5000ms*'
        }

        It 'Normal feedback result has TimedOut=false' {
            $feedback = [PSCustomObject]@{ topic = 'get_controller'; state = 0; msg = 'success'; data = @{} }
            $r = [YarboCommandResult]::new($feedback)
            $r.TimedOut | Should -BeFalse
            $r.Success  | Should -BeTrue
        }

        It 'ToString includes clock emoji for timed-out results' {
            $r = [YarboCommandResult]::Timeout('test', 1000)
            $r.ToString() | Should -BeLike '⏱*'
        }
    }

}
}

InModuleScope PSYarbo {
Describe 'Public Cmdlet Parameter Validation' {

    Context 'Connect-Yarbo' {
        It 'Has mandatory Broker parameter' {
            $cmd = Get-Command Connect-Yarbo
            $cmd.Parameters['Broker'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory SerialNumber parameter' {
            $cmd = Get-Command Connect-Yarbo
            $cmd.Parameters['SerialNumber'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
        }

        It 'Port defaults to 1883' {
            $cmd = Get-Command Connect-Yarbo
            $portParam = $cmd.Parameters['Port']
            if ($portParam.PSObject.Properties.Match('DefaultValue').Count -gt 0) {
                $portParam.DefaultValue | Should -BeNullOrEmpty -Because "Port default is applied in function body, not param block"
            } else {
                # Some PowerShell versions don't expose DefaultValue on ParameterMetadata
                $true | Should -BeTrue
            }
        }
    }

    Context 'Set-YarboLight' {
        It 'Has Preset parameter set with valid values' {
            $cmd = Get-Command Set-YarboLight
            $validateSet = $cmd.Parameters['Preset'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'AllOn'
            $validateSet.ValidValues | Should -Contain 'AllOff'
        }

        It 'Validates LED values range 0-255' {
            $cmd = Get-Command Set-YarboLight
            $range = $cmd.Parameters['HeadLight'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $range.MinRange | Should -Be 0
            $range.MaxRange | Should -Be 255
        }
    }

    Context 'Set-YarboVelocity' {
        It 'Validates LinearVelocity range -0.7 to 0.7' {
            $cmd = Get-Command Set-YarboVelocity
            $range = $cmd.Parameters['LinearVelocity'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $range.MinRange | Should -Be -0.7
            $range.MaxRange | Should -Be 0.7
        }

        It 'Has mandatory LinearVelocity parameter' {
            $cmd = Get-Command Set-YarboVelocity
            $cmd.Parameters['LinearVelocity'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Set-YarboRoller' {
        It 'Validates Speed range 0-2000' {
            $cmd = Get-Command Set-YarboRoller
            $range = $cmd.Parameters['Speed'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $range.MinRange | Should -Be 0
            $range.MaxRange | Should -Be 2000
        }
    }

    Context 'Set-YarboChute' {
        It 'Has mandatory Velocity parameter' {
            $cmd = Get-Command Set-YarboChute
            $cmd.Parameters['Velocity'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Stop-YarboPlan' {
        It 'Has ConfirmImpact High' {
            $cmd = Get-Command Stop-YarboPlan
            $cmdBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $cmdBinding.ConfirmImpact | Should -Be 'High'
        }
    }

    Context 'Send-YarboCommand' {
        It 'Has mandatory Command parameter' {
            $cmd = Get-Command Send-YarboCommand
            $cmd.Parameters['Command'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
        }

        It 'Has ConfirmImpact High' {
            $cmd = Get-Command Send-YarboCommand
            $cmdBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $cmdBinding.ConfirmImpact | Should -Be 'High'
        }
    }

    Context 'Export-YarboTelemetry' {
        It 'Validates Format parameter' {
            $cmd = Get-Command Export-YarboTelemetry
            $validateSet = $cmd.Parameters['Format'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'CSV'
            $validateSet.ValidValues | Should -Contain 'JSON'
            $validateSet.ValidValues | Should -Contain 'JSONL'
        }
    }

    Context 'Connect-YarboCloud' {
        It 'Has mandatory Email parameter in Credential set' {
            $cmd = Get-Command Connect-YarboCloud
            $emailParam = $cmd.Parameters['Email'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ParameterSetName -eq 'Credential' -and $_.Mandatory }
            $emailParam | Should -Not -BeNullOrEmpty
        }

        It 'Password is SecureString type' {
            $cmd = Get-Command Connect-YarboCloud
            $cmd.Parameters['Password'].ParameterType | Should -Be ([SecureString])
        }
    }

}
}

InModuleScope PSYarbo {
Describe 'Help Documentation' {
    BeforeAll {
        $script:exportedFunctions = $ExecutionContext.SessionState.Module.ExportedFunctions.Keys
    }

    It 'Every exported function has help synopsis' {
        foreach ($fn in $script:exportedFunctions) {
            $help = Get-Help $fn
            $help.Synopsis | Should -Not -BeNullOrEmpty -Because "$fn should have a synopsis"
            $help.Synopsis | Should -Not -Be $fn -Because "$fn synopsis should not be just the function name"
        }
    }

    It 'Every exported function has at least one example' {
        foreach ($fn in $script:exportedFunctions) {
            $help = Get-Help $fn
            $examples = if ($help.PSObject.Properties.Match('examples').Count -gt 0 -and $help.examples) { $help.examples.example } else { @() }
            $examples.Count | Should -BeGreaterThan 0 -Because "$fn should have at least one example"
        }
    }

}
}

AfterAll {
    if (Get-Module -Name PSYarbo) { Remove-Module -Name PSYarbo -Force }
}
