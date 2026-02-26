#
# Module manifest for module 'PSYarbo'
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'PSYarbo.psm1'

    # Version number of this module.
    ModuleVersion     = '0.1.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author            = 'Markus Lassfolk'

    # Company or vendor of this module
    CompanyName       = 'Community'

    # Copyright statement for this module
    Copyright         = '(c) Markus Lassfolk. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'PowerShell module for local control of Yarbo robot mowers via MQTT'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete this entry
    FunctionsToExport = @()

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete this entry
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete this entry
    AliasesToExport   = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess.
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('Yarbo', 'MQTT', 'RobotMower', 'IoT', 'HomeAutomation')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/markus-lassfolk/PSYarbo/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/markus-lassfolk/PSYarbo'

            # A URL to an icon representing this module.
            IconUri      = ''

            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release placeholder.'

            # Prerelease string of this module. For example: 'beta1', 'preview', 'rc1'
            Prerelease   = 'alpha'
        }
    }
}
