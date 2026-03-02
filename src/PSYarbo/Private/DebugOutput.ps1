<#
.SYNOPSIS
    Helpers for debug logging: env-based and -Debug switch support (aligns with python-yarbo #59).
#>

function Test-YarboDebugMode {
    <#
    .SYNOPSIS
        Returns true when debug output should be shown: -Debug was passed or PSYARBO_DEBUG env is set.
    #>
    [OutputType([bool])]
    param()
    if ($DebugPreference -eq 'Continue') { return $true }
    $v = $env:PSYARBO_DEBUG
    return ($v -eq '1' -or $v -eq 'true' -or $v -eq 'True')
}

function Test-YarboDebugRaw {
    <#
    .SYNOPSIS
        Returns true when debug output should show raw payloads (base64) instead of human-readable JSON.
    #>
    [OutputType([bool])]
    param()
    $v = $env:PSYARBO_DEBUG_RAW
    return ($v -eq '1' -or $v -eq 'true' -or $v -eq 'True')
}

function Write-YarboDebugMessage {
    <#
    .SYNOPSIS
        Writes a debug line. Uses Write-Debug when -Debug was passed; uses Write-Information when PSYARBO_DEBUG env is set so output shows without -Debug.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )
    $msg = Protect-YarboLogMessage -Message $Message
    if ($env:PSYARBO_DEBUG -eq '1' -or $env:PSYARBO_DEBUG -eq 'true' -or $env:PSYARBO_DEBUG -eq 'True') {
        Write-Information $msg -InformationAction Continue
    } else {
        Write-Debug $msg
    }
}
