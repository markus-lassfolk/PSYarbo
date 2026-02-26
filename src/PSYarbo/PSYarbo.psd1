@{
    RootModule        = 'PSYarbo.psm1'
    ModuleVersion     = '0.1.0'
    CompatiblePSEditions = @('Core')
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'Markus Lassfolk'
    CompanyName       = 'Community'
    Copyright         = '(c) Markus Lassfolk. All rights reserved.'
    Description       = 'PowerShell module for controlling Yarbo robot mowers via local MQTT and cloud REST API'
    PowerShellVersion = '7.4'
    # MQTTnet loaded via AssemblyLoadContext in PSYarbo.psm1 — not via RequiredAssemblies
    # RequiredAssemblies = @()
    FormatsToProcess  = @('PSYarbo.Format.ps1xml')
    FunctionsToExport = @(
        # Connection
        'Connect-Yarbo', 'Disconnect-Yarbo', 'Find-Yarbo',
        # Status
        'Get-YarboStatus', 'Get-YarboRobot', 'Get-YarboBattery', 'Get-YarboFirmware',
        # Control
        'Set-YarboLight', 'Start-YarboBuzzer', 'Stop-YarboBuzzer',
        'Start-YarboPlan', 'Stop-YarboPlan', 'Suspend-YarboPlan', 'Resume-YarboPlan',
        'Send-YarboCommand',
        # State
        'Resume-Yarbo', 'Suspend-Yarbo',
        # Manual Drive
        'Start-YarboManualDrive', 'Set-YarboVelocity', 'Set-YarboRoller', 'Set-YarboChute', 'Stop-YarboManualDrive',
        # Plans/Maps
        'Get-YarboPlan', 'New-YarboPlan', 'Remove-YarboPlan',
        'Get-YarboMap', 'Get-YarboSchedule', 'Set-YarboSchedule',
        # Telemetry
        'Get-YarboTelemetry', 'Watch-YarboTelemetry', 'Export-YarboTelemetry',
        # Cloud
        'Connect-YarboCloud', 'Get-YarboDevice', 'Get-YarboVideo', 'Get-YarboPlanHistory',
        # Utility
        'Test-YarboConnection', 'Get-YarboLog'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('Yarbo', 'Robot', 'Mower', 'MQTT', 'IoT', 'Automation', 'SnowBlower')
            LicenseUri   = 'https://github.com/markus-lassfolk/PSYarbo/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/markus-lassfolk/PSYarbo'
            ReleaseNotes = 'Initial implementation with full local MQTT and cloud REST support.'
            Prerelease   = 'alpha'
        }
    }
}
