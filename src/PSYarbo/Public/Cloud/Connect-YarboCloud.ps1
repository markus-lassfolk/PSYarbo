function Connect-YarboCloud {
    <#
.SYNOPSIS
    Authenticates with the Yarbo cloud API.

.DESCRIPTION
    Logs in to the Yarbo cloud service using email and RSA-encrypted password.
    Returns a YarboCloudSession object for use with cloud cmdlets.

.PARAMETER Email
    Your Yarbo account email.

.PARAMETER Password
    Your Yarbo account password as a SecureString.

.PARAMETER RefreshToken
    Use an existing refresh token instead of email/password.

.PARAMETER RsaPublicKeyPath
    Path to the RSA public key PEM file. Uses bundled key if not specified.

.EXAMPLE
    Connect-YarboCloud -Email 'user@example.com' -Password (Read-Host -AsSecureString)

.LINK
    Get-YarboDevice
    Get-YarboVideo
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'API tokens received from the Yarbo cloud API are wrapped in SecureString for safer in-memory storage')]
    [CmdletBinding(DefaultParameterSetName = 'Credential')]
    [OutputType([YarboCloudSession])]
    param(
        [Parameter(ParameterSetName = 'Credential')]
        [string]$Email,

        [Parameter(ParameterSetName = 'Credential')]
        [SecureString]$Password,

        [Parameter(Mandatory, ParameterSetName = 'Token')]
        [SecureString]$RefreshToken,

        [Parameter()]
        [string]$RsaPublicKeyPath
    )

    $session = [YarboCloudSession]::new()

    try {
        if ($PSCmdlet.ParameterSetName -eq 'Credential') {
            # Resolve email from env or config if not provided (issue #9)
            if (-not $Email) {
                $cfg = Get-YarboConfig -Overrides @{}
                $Email = $cfg['Email']
            }
            if (-not $Email) {
                throw [YarboCloudAuthException]::new(
                    'Email is required. Provide -Email, set $env:YARBO_EMAIL, or add Email to ~/.psyarbo/config.json.',
                    'EMAIL_REQUIRED'
                )
            }
            # When -Email without -Password, try stored credentials (issue #10)
            if (-not $Password) {
                $stored = Get-YarboCloudCredential -Email $Email
                if ($stored) {
                    if ($stored.RefreshToken) {
                        $session.Email = $Email
                        $session.RefreshToken = $stored.RefreshToken
                        $session.RefreshAuth()
                        if ($script:YarboCloudSession) { $script:YarboCloudSession.Dispose() }
                        $script:YarboCloudSession = $session
                        return $session
                    }
                    if ($stored.Password) { $Password = $stored.Password }
                }
                if (-not $Password) {
                    throw [YarboCloudAuthException]::new(
                        'Password is required. Provide -Password or save credentials with Connect-YarboCloud -Email -Password first.',
                        'PASSWORD_REQUIRED'
                    )
                }
            }
        }

        if ($PSCmdlet.ParameterSetName -eq 'Token') {
            $session.RefreshToken = $RefreshToken
            $session.RefreshAuth()
        } else {
            $session.Email = $Email
            $rsaKeyPath = if ($RsaPublicKeyPath) { $RsaPublicKeyPath }
            else { Join-Path $PSScriptRoot '../../../../assets/rsa_key/rsa_public_key.pem' }

            if (-not (Test-Path $rsaKeyPath)) {
                throw [YarboCloudAuthException]::new(
                    "RSA public key not found at '$rsaKeyPath'. Provide -RsaPublicKeyPath or ensure assets are bundled.",
                    'RSA_KEY_MISSING'
                )
            }

            $rsaPem = Get-Content $rsaKeyPath -Raw
            $rsa = [System.Security.Cryptography.RSA]::Create()
            try {
                $rsa.ImportFromPem($rsaPem.ToCharArray())

                # Convert SecureString to plain text only for the encryption step; clear immediately after.
                $plainPassword = [System.Net.NetworkCredential]::new('', $Password).Password
                try {
                    $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($plainPassword)
                    $encrypted = $rsa.Encrypt($passwordBytes, [System.Security.Cryptography.RSAEncryptionPadding]::Pkcs1)
                    $encryptedB64 = [Convert]::ToBase64String($encrypted)
                } finally {
                    # Clear plain-text password and derived bytes from memory as soon as no longer needed
                    $plainPassword = $null
                    if ($passwordBytes) {
                        [Array]::Clear($passwordBytes, 0, $passwordBytes.Length)
                    }
                }
            } finally {
                $rsa.Dispose()
            }

            Write-Verbose (Protect-YarboLogMessage "[Connect-YarboCloud] Routing via cloud REST → POST /yarbo/robot-service/robot/commonUser/login")

            $body = @{ username = $Email; password = $encryptedB64 } | ConvertTo-Json -Compress
            $content = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, 'application/json')
            $response = $session.HttpClient.PostAsync(
                "$($session.BaseUrl)/yarbo/robot-service/robot/commonUser/login",
                $content
            ).GetAwaiter().GetResult()

            $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

            if (-not $response.IsSuccessStatusCode) {
                throw [YarboCloudAuthException]::new(
                    "Login failed with HTTP $([int]$response.StatusCode): $responseBody",
                    ([int]$response.StatusCode).ToString()
                )
            }

            try {
                $result = $responseBody | ConvertFrom-Json
            } catch {
                throw [YarboCloudAuthException]::new(
                    "Login returned non-JSON response: $responseBody",
                    'INVALID_JSON'
                )
            }

            if (-not $result.success) {
                $codeStr = if ($null -ne $result.code) { $result.code.ToString() } else { 'UNKNOWN' }
                throw [YarboCloudAuthException]::new("Login failed: $($result.message)", $codeStr)
            }

            $session.AccessToken = ConvertTo-SecureString -String $result.data.accessToken -AsPlainText -Force
            $session.RefreshToken = ConvertTo-SecureString -String $result.data.refreshToken -AsPlainText -Force
            $session.TokenExpiry = [datetime]::UtcNow.AddSeconds($result.data.expiresIn)
            $session.BoundSerialNumbers = @($result.data.snList)

            # Persist refresh token for future sessions (issue #10: SecretManagement + email-keyed storage)
            try {
                Save-YarboCredential -Name 'CloudRefreshToken' -Value $session.RefreshToken
                if ($session.Email) {
                    Save-YarboCloudCredential -Email $session.Email -Password $Password -RefreshToken $session.RefreshToken
                }
                Write-Verbose "[Connect-YarboCloud] Refresh token saved via CredentialHelper for future sessions"
            } catch {
                Write-Verbose "[Connect-YarboCloud] Could not save refresh token: $($_.Exception.Message)"
            }
        }

        # Dispose any existing cloud session before overwriting
        if ($script:YarboCloudSession) {
            $script:YarboCloudSession.Dispose()
        }

        $script:YarboCloudSession = $session
    } catch {
        $session.Dispose()
        throw
    }
    $emailMsg = if ($session.Email) { " as $($session.Email)" } else { "" }
    Write-Verbose (Protect-YarboLogMessage "[Connect-YarboCloud] Authenticated$emailMsg")
    return $session
}
