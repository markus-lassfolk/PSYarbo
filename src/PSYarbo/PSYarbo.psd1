@{
    RootModule           = 'PSYarbo.psm1'
    ModuleVersion        = '0.1.0'
    CompatiblePSEditions = @('Core')
    GUID                 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author               = 'Markus Lassfolk'
    CompanyName          = 'Community'
    Copyright            = '(c) Markus Lassfolk. All rights reserved.'
    Description          = 'PowerShell module for controlling Yarbo robot mowers via local MQTT and cloud REST API'
    PowerShellVersion    = '7.4'
    # MQTTnet loaded via AssemblyLoadContext in PSYarbo.psm1 — not via RequiredAssemblies
    # RequiredAssemblies = @()
    # Load class definitions before root module so [YarboRobot], [YarboConnection], etc. are visible to OutputType/attributes
    ScriptsToProcess     = @(
        'Classes/YarboExceptions.ps1'
        'Classes/YarboLightState.ps1'
        'Classes/YarboCommandResult.ps1'
        'Classes/YarboTelemetry.ps1'
        'Classes/YarboPlan.ps1'
        'Classes/YarboSchedule.ps1'
        'Classes/YarboRobot.ps1'
        'Classes/YarboGlobalParams.ps1'
        'Classes/YarboEndpoint.ps1'
        'Classes/YarboConnection.ps1'
        'Classes/YarboCloudSession.ps1'
    )
    FormatsToProcess     = @('PSYarbo.Format.ps1xml')
    # Types loaded in .psm1 with Update-TypeData -Force to avoid "already present" on re-import
    # TypesToProcess       = @('PSYarbo.Types.ps1xml')
    FunctionsToExport    = @(
        # Connection
        'Connect-Yarbo', 'Disconnect-Yarbo', 'Find-Yarbo', 'Find-YarboDevice', 'Invoke-YarboMqttSniff',
        # Status
        'Get-YarboStatus', 'Get-YarboRobot', 'Get-YarboBattery', 'Get-YarboFirmware',
        'Get-YarboGlobalParams',
        # Control
        'Set-YarboLight', 'Start-YarboBuzzer', 'Stop-YarboBuzzer',
        'Start-YarboPlan', 'Stop-YarboPlan', 'Suspend-YarboPlan', 'Resume-YarboPlan',
        'Send-YarboCommand', 'Send-YarboReturnToDock',
        'Set-YarboGlobalParams', 'Set-YarboBladeSpeed', 'Set-YarboChargeLimit',
        # Robot Control
        'Stop-YarboEmergency', 'Unlock-YarboEmergency', 'Stop-Yarbo',
        'Restart-YarboContainer', 'Stop-YarboShutdown', 'Start-YarboRecharge',
        # Lights & Sound
        'Set-YarboHeadLight', 'Set-YarboRoofLights', 'Set-YarboLaser',
        'Set-YarboSound', 'Start-YarboSong',
        # Camera & Detection
        'Set-YarboCamera', 'Set-YarboPersonDetect', 'Set-YarboUSB',
        # State
        'Resume-Yarbo', 'Suspend-Yarbo',
        # Manual Drive
        'Start-YarboManualDrive', 'Set-YarboVelocity', 'Set-YarboRoller', 'Set-YarboChute', 'Stop-YarboManualDrive',
        # Plans/Maps/Schedules
        'Get-YarboPlan', 'New-YarboPlan', 'Remove-YarboPlan',
        'Get-YarboMap', 'Get-YarboSchedule', 'Set-YarboSchedule', 'Remove-YarboSchedule',
        # Plans & Scheduling
        'Get-YarboAllPlans', 'Remove-YarboAllPlans', 'Invoke-YarboPlanAction', 'Get-YarboSchedules',
        # Navigation & Maps
        'Start-YarboWaypoint', 'Get-YarboRechargePoint', 'Save-YarboChargingPoint',
        'Get-YarboCleanArea', 'Get-YarboMapBackup', 'Save-YarboMapBackup',
        # WiFi & Connectivity
        'Get-YarboWifiList', 'Get-YarboConnectedWifi', 'Get-YarboSavedWifiList', 'Start-YarboHotspot', 'Get-YarboHubInfo',
        # Diagnostics
        'Get-YarboBatteryCellTemps', 'Get-YarboMotorTemps', 'Get-YarboBodyCurrent', 'Get-YarboHeadCurrent',
        'Get-YarboSpeed', 'Get-YarboOdometer', 'Get-YarboProductCode', 'Get-YarboNoChargePeriod',
        # Telemetry
        'Get-YarboTelemetry', 'Watch-YarboTelemetry', 'Export-YarboTelemetry',
        # Cloud
        'Connect-YarboCloud', 'Get-YarboDevice', 'Get-YarboVideo', 'Get-YarboPlanHistory',
        'Set-YarboRobotName', 'Add-YarboRobotBinding', 'Remove-YarboRobotBinding',
        'Get-YarboNotificationSetting', 'Get-YarboDeviceMessage',
        # Utility
        'Test-YarboConnection', 'Get-YarboLog', 'Get-YarboMqttRecordingReport', 'Export-YarboSupportBundle'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @('Return-YarboToDock')
    PrivateData          = @{
        PSData = @{
            Tags         = @('Yarbo', 'Robot', 'Mower', 'MQTT', 'IoT', 'Automation', 'SnowBlower')
            LicenseUri   = 'https://github.com/markus-lassfolk/PSYarbo/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/markus-lassfolk/PSYarbo'
            ReleaseNotes = 'Initial implementation with full local MQTT and cloud REST support.'
            Prerelease   = 'alpha'
        }
    }
}
