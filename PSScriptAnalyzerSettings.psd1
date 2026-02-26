#
# PSScriptAnalyzer settings for PSYarbo
# Docs: https://github.com/PowerShell/PSScriptAnalyzer
#

@{
    # Analyze rules of these severities (Error and Warning cause CI failure)
    Severity     = @('Error', 'Warning')

    # Rules to explicitly include (on top of defaults)
    IncludeRules = @(
        # Security
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingUsernameAndPasswordParams',

        # Best practice
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidGlobalVars',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingPositionalParameters',
        'PSUseApprovedVerbs',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSProvideCommentHelp',
        'PSAvoidDefaultValueForMandatoryParameter',
        'PSAvoidDefaultValueSwitchParameter',
        'PSUseSingularNouns',
        'PSAvoidUsingInvokeExpression',

        # Code style
        'PSPlaceOpenBrace',
        'PSPlaceCloseBrace',
        'PSUseConsistentIndentation',
        'PSUseConsistentWhitespace',
        'PSAlignAssignmentStatement',

        # Performance
        'PSAvoidUsingWMICmdlet',
        'PSAvoidUsingEmptyCatchBlock'
    )

    # Rules to explicitly exclude
    ExcludeRules = @(
        # Community module — Write-Host is acceptable for user-facing verbose output
        'PSAvoidUsingWriteHost'
    )

    Rules        = @{
        PSUseConsistentIndentation  = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind                = 'space'
        }
        PSUseConsistentWhitespace   = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $true
            CheckSeparator                          = $true
            CheckParameter                          = $false
            IgnoreAssignmentOperatorInsideHashTable = $true
        }
        PSPlaceOpenBrace            = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace           = @{
            Enable             = $true
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
        PSAlignAssignmentStatement  = @{
            Enable         = $true
            CheckHashtable = $true
        }
        PSProvideCommentHelp        = @{
            Enable                  = $true
            ExportedOnly            = $true
            BlockComment            = $true
            VSCodeSnippetCorrection = $false
            Placement               = 'before'
        }
    }
}
