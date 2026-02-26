<#
.SYNOPSIS
    GlitchTip/Sentry error reporting for PSYarbo.
.DESCRIPTION
    Sends unhandled exceptions to GlitchTip using the Sentry store API.
    Disabled by default (opt-in). Enable by setting $env:YARBO_SENTRY_DSN to your Sentry DSN.
#>

$script:ErrorReportingDSN = $null
$script:ErrorReportingEnabled = $false

function Initialize-YarboErrorReporting {
    [CmdletBinding()]
    param(
        [string]$DSN = $env:YARBO_SENTRY_DSN
    )

    # Opt-in: disabled by default unless YARBO_SENTRY_DSN is explicitly set
    if (-not $DSN) {
        $script:ErrorReportingEnabled = $false
        return
    }

    $script:ErrorReportingDSN = $DSN
    $script:ErrorReportingEnabled = $true
}

function Send-YarboErrorReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception,
        [hashtable]$Tags = @{},
        [hashtable]$Extra = @{}
    )

    if (-not $script:ErrorReportingEnabled -or -not $script:ErrorReportingDSN) {
        return
    }

    try {
        # Parse DSN: http://{key}@{host}/{project_id}
        $uri = [uri]$script:ErrorReportingDSN
        $key = $uri.UserInfo
        $projectId = $uri.AbsolutePath.TrimStart('/')
        $storeUrl = "$($uri.Scheme)://$($uri.Host):$($uri.Port)/api/$projectId/store/"

        # Scrub sensitive data from exception message
        $message = $Exception.Message -replace '(password|token|secret|key)\s*[=:]\s*\S+', '$1=[REDACTED]'

        $payload = @{
            event_id    = [guid]::NewGuid().ToString('N')
            timestamp   = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss')
            platform    = 'other'
            level       = 'error'
            logger      = 'PSYarbo'
            server_name = $env:COMPUTERNAME
            environment = if ($env:YARBO_ENVIRONMENT) { $env:YARBO_ENVIRONMENT } else { 'production' }
            tags        = $Tags
            extra       = $Extra
            exception   = @{
                values = @(@{
                        type       = $Exception.GetType().Name
                        value      = $message
                        stacktrace = @{
                            frames = @(
                                $Exception.ScriptStackTrace -split "`n" | ForEach-Object {
                                    @{ filename = $_; lineno = 0; function = $_ }
                                }
                            )
                        }
                    })
            }
        } | ConvertTo-Json -Depth 10

        $headers = @{
            'Content-Type'  = 'application/json'
            'X-Sentry-Auth' = "Sentry sentry_version=7,sentry_client=psyarbo/0.1.0,sentry_key=$key"
        }

        Invoke-RestMethod -Uri $storeUrl -Method POST -Body $payload -Headers $headers -TimeoutSec 5 | Out-Null
    } catch {
        # Never let error reporting itself cause failures
        Write-Verbose "Error reporting failed: $_"
    }
}
