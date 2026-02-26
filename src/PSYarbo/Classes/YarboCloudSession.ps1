class YarboCloudSession {
    [string]$Email
    [string]$BaseUrl = 'https://4zx17x5q7l.execute-api.us-east-1.amazonaws.com/Stage'
    [datetime]$TokenExpiry
    [string[]]$BoundSerialNumbers

    hidden [SecureString]$AccessToken
    hidden [SecureString]$RefreshToken
    hidden [System.Net.Http.HttpClient]$HttpClient

    YarboCloudSession() {
        $this.HttpClient = [System.Net.Http.HttpClient]::new()
        $this.HttpClient.DefaultRequestHeaders.Add('User-Agent', 'PSYarbo/0.1.0')
    }

    [PSCustomObject] Invoke([string]$method, [string]$path, [hashtable]$body) {
        $url = "$($this.BaseUrl)$path"
        $bearer = $this.GetBearerToken()
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
        return $responseBody | ConvertFrom-Json
    }

    [void] RefreshAuth() {
        $refreshPlain = [System.Net.NetworkCredential]::new('', $this.RefreshToken).Password
        $body = @{ refresh_token = $refreshPlain } | ConvertTo-Json -Compress
        $content = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, 'application/json')
        $response = $this.HttpClient.PostAsync(
            "$($this.BaseUrl)/yarbo/robot-service/robot/commonUser/refreshToken",
            $content
        ).GetAwaiter().GetResult()
        $result = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json

        if ($result.success) {
            $this.AccessToken = ConvertTo-SecureString -String $result.data.accessToken -AsPlainText -Force
            $this.TokenExpiry = [datetime]::UtcNow.AddSeconds($result.data.expiresIn)
        } else {
            throw [YarboCloudAuthException]::new("Token refresh failed: $($result.message)", $result.code)
        }
    }

    [bool] IsExpired() { return [datetime]::UtcNow -ge $this.TokenExpiry }

    [string] GetBearerToken() {
        if ($this.IsExpired()) { $this.RefreshAuth() }
        return [System.Net.NetworkCredential]::new('', $this.AccessToken).Password
    }

    [string] ToString() { return "YarboCloud[$($this.Email)]" }
}
