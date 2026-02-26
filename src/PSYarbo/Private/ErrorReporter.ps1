<#
.SYNOPSIS
    GlitchTip/Sentry error reporting for PSYarbo.
.DESCRIPTION
    Sends unhandled exceptions to GlitchTip using the Sentry store API.
    Opt-in: disabled by default. Enable by setting $env:YARBO_SENTRY_DSN to your DSN.
#>

$script:ErrorReportingDSN = $null
$script:ErrorReportingEnabled = $false

function Initialize-YarboErrorReporting {
    [CmdletBinding()]
    param(
        [string]$DSN = $env:YARBO_SENTRY_DSN
    )

    # Opt-in: only enable if YARBO_SENTRY_DSN is explicitly provided
    if (-not $DSN) {
        $script:ErrorReportingEnabled = $false
        return
    }

    $script:ErrorReportingDSN = $DSN
    $script:ErrorReportingEnabled = $true
}
