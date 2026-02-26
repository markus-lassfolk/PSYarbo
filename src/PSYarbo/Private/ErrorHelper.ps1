function New-YarboError {
    <#
    .SYNOPSIS
        Creates a standardized ErrorRecord with PSYarbo.<Category>.<Command> ErrorId format.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'New-YarboError creates and returns an ErrorRecord object; it does not modify any system or module state')]
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$ErrorId,
        [System.Management.Automation.ErrorCategory]$Category = 'NotSpecified',
        [object]$TargetObject,
        [System.Exception]$Exception
    )

    $ex = if ($Exception) { $Exception } else { [YarboException]::new($Message, $ErrorId) }
    $record = [System.Management.Automation.ErrorRecord]::new($ex, $ErrorId, $Category, $TargetObject)
    return $record
}
