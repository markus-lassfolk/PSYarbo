#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Unit tests for New-YarboError (ErrorHelper).
#>

BeforeAll {
    $scriptRoot = Join-Path $PSScriptRoot '..' '..' 'src' 'PSYarbo'
    . (Join-Path $scriptRoot 'Classes' 'YarboExceptions.ps1')
    . (Join-Path $scriptRoot 'Private' 'ErrorHelper.ps1')
}

Describe 'New-YarboError' {
    It 'Returns an ErrorRecord' {
        $err = New-YarboError -Message 'Test' -ErrorId 'PSYarbo.Test.Id'
        $err | Should -Not -BeNullOrEmpty
        $err | Should -BeOfType [System.Management.Automation.ErrorRecord]
    }

    It 'Sets ErrorId and Message' {
        $err = New-YarboError -Message 'Timeout' -ErrorId 'PSYarbo.Timeout.GetDeviceMsg'
        $err.FullyQualifiedErrorId | Should -Be 'PSYarbo.Timeout.GetDeviceMsg'
        $err.Exception.Message | Should -Be 'Timeout'
    }

    It 'Accepts Category and TargetObject' {
        $target = [PSCustomObject]@{ Broker = '192.0.2.1' }
        $err = New-YarboError -Message 'Failed' -ErrorId 'PSYarbo.Fail' -Category OperationTimeout -TargetObject $target
        $err.CategoryInfo.Category | Should -Be 'OperationTimeout'
        $err.TargetObject.Broker | Should -Be '192.0.2.1'
    }
}
