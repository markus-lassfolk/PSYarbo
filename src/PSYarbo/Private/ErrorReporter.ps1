<#
.SYNOPSIS
    GlitchTip/Sentry error reporting for PSYarbo.
.DESCRIPTION
    Sends unhandled exceptions to GlitchTip using the Sentry store API.
    Enabled by default (opt-out). Disable by setting $env:YARBO_SENTRY_DSN to an empty string.
#>

$script:ErrorReportingDSN = $null
$script:ErrorReportingEnabled = $false

function Initialize-YarboErrorReporting {
    [CmdletBinding()]
    param(
        [string]$DSN = $env:YARBO_SENTRY_DSN
    )

    # Opt-out: enabled by default unless YARBO_SENTRY_DSN is explicitly set to empty string
    if ($env:YARBO_SENTRY_DSN -eq '') {
        $script:ErrorReportingEnabled = $false
        return
    }

    if (-not $DSN) {
        $DSN = 'http://f8ce85f9b85c4f33a76f1df9881ef897@192.168.1.99:8000/3'
    }

    $script:ErrorReportingDSN = $DSN
    $script:ErrorReportingEnabled = $true
}
