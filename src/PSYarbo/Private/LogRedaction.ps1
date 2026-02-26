function Protect-YarboLogMessage {
    <#
    .SYNOPSIS
        Scrubs sensitive data (JWT tokens, auth headers, credential fields) from log messages.
    #>
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    # Scrub JWT tokens (eyJ...)
    $Message = $Message -replace 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+', '[REDACTED-JWT]'

    # Scrub Authorization: Bearer headers
    $Message = $Message -replace '(?i)(Authorization:\s*Bearer\s+)\S+', '${1}[REDACTED]'

    # Scrub refresh_token values (v1. prefix or generic assignment)
    $Message = $Message -replace '(refresh_token["''`]?\s*[:=]\s*["''`]?)v1\.[^\s"'',}]+', '${1}[REDACTED]'

    # Scrub accessToken JSON values  (e.g. "accessToken":"...")
    $Message = $Message -replace '("accessToken"\s*:\s*")[^"]+(")', '${1}[REDACTED]${2}'
    $Message = $Message -replace "('accessToken'\s*:\s*')[^']+(')", '${1}[REDACTED]${2}'

    # Scrub refreshToken JSON values
    $Message = $Message -replace '("refreshToken"\s*:\s*")[^"]+(")', '${1}[REDACTED]${2}'
    $Message = $Message -replace "('refreshToken'\s*:\s*')[^']+(')", '${1}[REDACTED]${2}'

    # Scrub query-string token params (?token=... &access_token=... &refresh_token=...)
    $Message = $Message -replace '([?&](?:token|access_token|refresh_token|id_token|api_key)=)[^&\s"'']+', '${1}[REDACTED]'

    # Scrub password fields
    $Message = $Message -replace '("password"\s*:\s*")[^"]+(")', '${1}[REDACTED]${2}'

    return $Message
}
