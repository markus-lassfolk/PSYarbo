<#
.SYNOPSIS
    Helper functions for storing and retrieving Yarbo credentials.
.DESCRIPTION
    Uses Microsoft.PowerShell.SecretManagement if available, falls back to
    encrypted DPAPI file (Windows) or base64-encoded file (non-Windows).
    Intended primarily for storing cloud JWT refresh tokens between sessions.
#>

$script:YarboCredentialDir = Join-Path $HOME '.psyarbo'
$script:YarboCredentialFile = Join-Path $script:YarboCredentialDir 'credentials.json'

function Save-YarboCredential {
    <#
    .SYNOPSIS
        Saves a named Yarbo credential (SecureString) for future sessions.
    .PARAMETER Name
        Logical name for the credential (e.g., 'CloudRefreshToken').
    .PARAMETER Value
        The credential value as a SecureString.
    .PARAMETER VaultName
        SecretManagement vault name to use. Defaults to 'PSYarbo'.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Private credential helper — called only from Connect-YarboCloud which gates ShouldProcess')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [SecureString]$Value,

        [Parameter()]
        [string]$VaultName = 'PSYarbo'
    )

    # Prefer SecretManagement if available
    if (Get-Command -Name 'Set-Secret' -ErrorAction SilentlyContinue) {
        try {
            Set-Secret -Name "PSYarbo.$Name" -Secret $Value -Vault $VaultName -ErrorAction Stop
            Write-Verbose "PSYarbo: Saved credential '$Name' to SecretManagement vault '$VaultName'"
            return
        } catch {
            Write-Warning "PSYarbo: SecretManagement unavailable or vault missing ($($_.Exception.Message)). Falling back to file storage."
        }
    }

    # Fallback: file-based storage
    $plain = [System.Net.NetworkCredential]::new('', $Value).Password
    try {
        $stored = if ($IsWindows) {
            [Convert]::ToBase64String(
                [System.Security.Cryptography.ProtectedData]::Protect(
                    [System.Text.Encoding]::UTF8.GetBytes($plain),
                    $null,
                    [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                )
            )
        } else {
            [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($plain))
        }
    } finally {
        $plain = $null
    }

    if (-not (Test-Path $script:YarboCredentialDir)) {
        $null = New-Item -ItemType Directory -Path $script:YarboCredentialDir -Force
    }
    if (-not $IsWindows) {
        try {
            [System.IO.File]::SetUnixFileMode($script:YarboCredentialDir, 'UserRead, UserWrite, UserExecute')
        } catch {
            Write-Warning "PSYarbo: Could not set directory permissions: $($_.Exception.Message)"
        }
    }

    $creds = @{}
    if (Test-Path $script:YarboCredentialFile) {
        try {
            $existing = Get-Content $script:YarboCredentialFile -Raw | ConvertFrom-Json
            $existing.PSObject.Properties | ForEach-Object { $creds[$_.Name] = $_.Value }
        } catch { $null = $_ }
    }

    $creds[$Name] = @{
        Value     = $stored
        Protected = $IsWindows
        Saved     = [datetime]::UtcNow.ToString('o')
    }
    if (-not $IsWindows -and -not (Test-Path $script:YarboCredentialFile)) {
        try {
            $null = New-Item -ItemType File -Path $script:YarboCredentialFile -Force
            [System.IO.File]::SetUnixFileMode($script:YarboCredentialFile, 'UserRead, UserWrite')
        } catch {
            Write-Warning "PSYarbo: Could not create file with secure permissions: $($_.Exception.Message)"
        }
    }
    $creds | ConvertTo-Json -Depth 5 | Set-Content -Path $script:YarboCredentialFile -Encoding UTF8
    if (-not $IsWindows) {
        try {
            [System.IO.File]::SetUnixFileMode($script:YarboCredentialFile, 'UserRead, UserWrite')
        } catch {
            Write-Warning "PSYarbo: Could not set file permissions: $($_.Exception.Message)"
        }
    }
    Write-Verbose "PSYarbo: Saved credential '$Name' to $script:YarboCredentialFile"
}

function Get-YarboCredential {
    <#
    .SYNOPSIS
        Retrieves a named Yarbo credential as a SecureString.
    .PARAMETER Name
        Logical name of the credential to retrieve.
    .PARAMETER VaultName
        SecretManagement vault name. Defaults to 'PSYarbo'.
    .OUTPUTS
        [SecureString] or $null if not found.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'Credential retrieved from encrypted file storage must be re-wrapped in SecureString')]
    [OutputType([SecureString])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$VaultName = 'PSYarbo'
    )

    # Try SecretManagement first
    if (Get-Command -Name 'Get-Secret' -ErrorAction SilentlyContinue) {
        try {
            $secret = Get-Secret -Name "PSYarbo.$Name" -Vault $VaultName -ErrorAction Stop
            Write-Verbose "PSYarbo: Retrieved credential '$Name' from SecretManagement vault '$VaultName'"
            return $secret
        } catch {
            Write-Verbose "PSYarbo: Credential '$Name' not found in vault '$VaultName', trying file."
        }
    }

    # Fallback: file-based storage
    if (-not (Test-Path $script:YarboCredentialFile)) { return $null }

    try {
        $creds = Get-Content $script:YarboCredentialFile -Raw | ConvertFrom-Json
        $entry = $creds.PSObject.Properties[$Name]?.Value
        if (-not $entry) { return $null }

        $bytes = [Convert]::FromBase64String($entry.Value)
        $plain = if ($entry.Protected -and $IsWindows) {
            [System.Text.Encoding]::UTF8.GetString(
                [System.Security.Cryptography.ProtectedData]::Unprotect(
                    $bytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                )
            )
        } else {
            [System.Text.Encoding]::UTF8.GetString($bytes)
        }

        $secure = ConvertTo-SecureString -String $plain -AsPlainText -Force
        $plain = $null
        Write-Verbose "PSYarbo: Retrieved credential '$Name' from file store"
        return $secure
    } catch {
        Write-Warning "PSYarbo: Could not retrieve credential '$Name': $($_.Exception.Message)"
        return $null
    }
}

function Get-YarboCloudCredential {
    <#
    .SYNOPSIS
        Retrieves stored cloud credentials for an email (password and/or refresh token).
    .DESCRIPTION
        Returns a hashtable with Password and RefreshToken (SecureString or $null) for the given email.
        Used by Connect-YarboCloud when -Email is provided without -Password.
    .PARAMETER Email
        The account email used as the credential key.
    .OUTPUTS
        [hashtable] @{ Password = [SecureString]; RefreshToken = [SecureString] } or $null if neither found.
    #>
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Email
    )

    $safeKey = $Email -replace '[^a-zA-Z0-9._@-]', '_'
    $passwordName = "$safeKey-Password"
    $tokenName = "$safeKey-RefreshToken"

    $password = Get-YarboCredential -Name $passwordName
    $refreshToken = Get-YarboCredential -Name $tokenName
    if (-not $password -and -not $refreshToken) { return $null }
    return @{ Password = $password; RefreshToken = $refreshToken }
}

function Save-YarboCloudCredential {
    <#
    .SYNOPSIS
        Saves cloud password and optional refresh token keyed by email (SecretManagement or file fallback).
    .PARAMETER Email
        The account email (used as the credential key).
    .PARAMETER Password
        The account password (SecureString).
    .PARAMETER RefreshToken
        Optional refresh token to store for future sessions.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Private credential helper')]
    param(
        [Parameter(Mandatory)]
        [string]$Email,

        [Parameter(Mandatory)]
        [SecureString]$Password,

        [Parameter()]
        [SecureString]$RefreshToken
    )

    $safeKey = $Email -replace '[^a-zA-Z0-9._@-]', '_'
    Save-YarboCredential -Name "$safeKey-Password" -Value $Password
    if ($RefreshToken) {
        Save-YarboCredential -Name "$safeKey-RefreshToken" -Value $RefreshToken
    }
}

function Remove-YarboCredential {
    <#
    .SYNOPSIS
        Removes a stored Yarbo credential.
    .PARAMETER Name
        Logical name of the credential to remove.
    .PARAMETER VaultName
        SecretManagement vault name. Defaults to 'PSYarbo'.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Private credential helper — state-change gate is in the calling public cmdlet')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$VaultName = 'PSYarbo'
    )

    # Try SecretManagement first
    if (Get-Command -Name 'Remove-Secret' -ErrorAction SilentlyContinue) {
        try {
            Remove-Secret -Name "PSYarbo.$Name" -Vault $VaultName -ErrorAction Stop
            Write-Verbose "PSYarbo: Removed credential '$Name' from SecretManagement vault '$VaultName'"
            return
        } catch {
            Write-Verbose "PSYarbo: Could not remove from vault: $($_.Exception.Message)"
        }
    }

    # Fallback: file-based
    if (-not (Test-Path $script:YarboCredentialFile)) { return }

    try {
        $creds = @{}
        $existing = Get-Content $script:YarboCredentialFile -Raw | ConvertFrom-Json
        $existing.PSObject.Properties | ForEach-Object { $creds[$_.Name] = $_.Value }
        $creds.Remove($Name) | Out-Null
        $creds | ConvertTo-Json -Depth 5 | Set-Content -Path $script:YarboCredentialFile -Encoding UTF8
        if (-not $IsWindows) {
            try {
                [System.IO.File]::SetUnixFileMode($script:YarboCredentialFile, 'UserRead, UserWrite')
            } catch {
                Write-Warning "PSYarbo: Could not set file permissions: $($_.Exception.Message)"
            }
        }
        Write-Verbose "PSYarbo: Removed credential '$Name' from file store"
    } catch {
        Write-Warning "PSYarbo: Could not remove credential '$Name': $($_.Exception.Message)"
    }
}
