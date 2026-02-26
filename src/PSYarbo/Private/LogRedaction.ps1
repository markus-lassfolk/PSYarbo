function Protect-YarboLogMessage {
    <#
    .SYNOPSIS
        Scrubs sensitive data (JWT tokens, auth headers) from log messages.
    #>
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    # Scrub JWT tokens (eyJ...)
    $Message = $Message -replace 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+', '[REDACTED-JWT]'
    # Scrub Authorization headers
    $Message = $Message -replace '(?i)(Authorization:\s*Bearer\s+)\S+', '${1}[REDACTED]'
    # Scrub refresh tokens (v1. prefixed)
    $Message = $Message -replace '(refresh_token["''`]?\s*[:=]\s*["''`]?)v1\.[^\s"'',}]+', '${1}[REDACTED]'
    return $Message
}
