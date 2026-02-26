[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'API tokens received from the network are wrapped in SecureString for safer in-memory storage; no alternative without losing the security benefit')]
class YarboCloudSession {
    [string]$Email
    [string]$BaseUrl = 'https://4zx17x5q7l.execute-api.us-east-1.amazonaws.com/Stage'
    [datetime]$TokenExpiry
    [string[]]$BoundSerialNumbers

    hidden [SecureString]$AccessToken
    hidden [SecureString]$RefreshToken
    hidden [System.Net.Http.HttpClient]$HttpClient

    # Retry policy constants
    hidden static [int]$MaxRetries = 3
    hidden static [int[]]$RetryDelay = @(1000, 3000, 9000)  # exponential ms

    YarboCloudSession() {
        $this.HttpClient = [System.Net.Http.HttpClient]::new()
        $this.HttpClient.DefaultRequestHeaders.Add('User-Agent', 'PSYarbo/0.1.0')
        $this.HttpClient.Timeout = [TimeSpan]::FromSeconds(30)
    }

    [PSCustomObject] Invoke([string]$method, [string]$path, [hashtable]$body) {
        return $this.InvokeWithRetry($method, $path, $body)
    }

    hidden [PSCustomObject] InvokeWithRetry([string]$method, [string]$path, [hashtable]$body) {
        $url = "$($this.BaseUrl)$path"
        $bearer = $this.GetBearerToken()

        $isIdempotent = ($method -eq 'GET')
        $lastError = $null

        $maxAttempts = if ($isIdempotent) { [YarboCloudSession]::MaxRetries + 1 } else { 1 }

        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
            try {
                $request = [System.Net.Http.HttpRequestMessage]::new(
                    [System.Net.Http.HttpMethod]::new($method),
                    $url
                )
                $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $bearer)

                if ($body) {
                    $json = $body | ConvertTo-Json -Compress -Depth 10
                    $request.Content = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
                }

                $response = $this.HttpClient.SendAsync($request).GetAwaiter().GetResult()
                $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

                # Check HTTP status before parsing JSON
                if (-not $response.IsSuccessStatusCode) {
                    $statusCode = [int]$response.StatusCode
                    # Try to extract a message from the body if it looks like JSON
                    $errMsg = $responseBody
                    try {
                        $errObj = $responseBody | ConvertFrom-Json -ErrorAction Stop
                        if ($errObj.message) { $errMsg = $errObj.message }
                        elseif ($errObj.error) { $errMsg = $errObj.error }
                    } catch {
                        Write-Debug "Could not parse error body as JSON: $($_.Exception.Message)"
                    }
                    throw [System.Net.Http.HttpRequestException]::new(
                        "HTTP $statusCode from $method $path : $errMsg"
                    )
                }

                # Try to parse JSON; surface raw body on failure
                try {
                    return $responseBody | ConvertFrom-Json
                } catch {
                    throw [System.InvalidOperationException]::new(
                        "Non-JSON response from $method $path (HTTP $([int]$response.StatusCode)): $responseBody"
                    )
                }
            } catch {
                $lastError = $_
                if ($isIdempotent -and $attempt -lt $maxAttempts) {
                    $delayMs = [YarboCloudSession]::RetryDelay[$attempt - 1]
                    Write-Warning "[YarboCloudSession] $method $path attempt $attempt/$maxAttempts failed: $($_.Exception.Message). Retrying in ${delayMs}ms…"
                    [System.Threading.Thread]::Sleep($delayMs)
                    # Re-acquire token in case of 401
                    if ($_.Exception.Message -like '*HTTP 401*') {
                        $this.RefreshAuth()
                        $bearer = $this.GetBearerToken()
                    }
                }
            }
        }

        throw $lastError
    }

    [void] RefreshAuth() {
        $refreshPlain = [System.Net.NetworkCredential]::new('', $this.RefreshToken).Password
        $body = @{ refresh_token = $refreshPlain } | ConvertTo-Json -Compress
        $content = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, 'application/json')

        $response = $this.HttpClient.PostAsync(
            "$($this.BaseUrl)/yarbo/robot-service/robot/commonUser/refreshToken",
            $content
        ).GetAwaiter().GetResult()

        $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

        if (-not $response.IsSuccessStatusCode) {
            throw [YarboCloudAuthException]::new(
                "Token refresh failed with HTTP $([int]$response.StatusCode): $responseBody",
                [int]$response.StatusCode
            )
        }

        try {
            $result = $responseBody | ConvertFrom-Json
        } catch {
            throw [YarboCloudAuthException]::new(
                "Token refresh returned non-JSON response: $responseBody",
                0
            )
        }

        if ($result.success) {
            $this.AccessToken = ConvertTo-SecureString -String $result.data.accessToken  -AsPlainText -Force
            $this.TokenExpiry = [datetime]::UtcNow.AddSeconds($result.data.expiresIn)
            if ($result.data.refreshToken) {
                $this.RefreshToken = ConvertTo-SecureString -String $result.data.refreshToken -AsPlainText -Force
            }
        } else {
            throw [YarboCloudAuthException]::new("Token refresh failed: $($result.message)", [string]$result.code)
        }
    }

    [bool] IsExpired() { return [datetime]::UtcNow -ge $this.TokenExpiry }

    [string] GetBearerToken() {
        if ($this.IsExpired()) { $this.RefreshAuth() }
        return [System.Net.NetworkCredential]::new('', $this.AccessToken).Password
    }

    [string] ToString() { return "YarboCloud[$($this.Email)]" }

    # Implement IDisposable — dispose HttpClient when session is no longer needed.
    [void] Dispose() {
        if ($null -ne $this.HttpClient) {
            $this.HttpClient.Dispose()
            $this.HttpClient = $null
        }
    }
}
