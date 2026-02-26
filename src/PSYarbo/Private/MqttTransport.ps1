function Send-MqttCommand {
    <#
    .SYNOPSIS
        Core MQTT publish + response wait with single-inflight semaphore.
    #>
    [CmdletBinding()]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(Mandatory)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter()]
        [hashtable]$Payload = @{},

        [Parameter()]
        [int]$TimeoutMs = 5000,

        [Parameter()]
        [switch]$NoWait
    )

    $topic = "snowbot/$($Connection.SerialNumber)/app/$Command"
    Write-Verbose (Protect-YarboLogMessage "[Send-MqttCommand] Routing via local MQTT → $topic")

    # Compress payload
    $compressed = ConvertTo-ZlibPayload -Payload $Payload
    Write-Debug (Protect-YarboLogMessage "[Send-MqttCommand] Payload JSON: $($Payload | ConvertTo-Json -Compress)")

    # Acquire semaphore to serialize commands
    if (-not $Connection.CommandSemaphore.Wait(30000)) {
        throw [YarboTimeoutException]::new($Command, 30000)
    }

    try {
        # Clear any stale responses from queue
        $stale = $null
        while ($Connection.ResponseQueue.TryDequeue([ref]$stale)) { }

        # Build and publish MQTT message
        if ($null -eq $Connection.MqttClient) {
            throw [YarboConnectionException]::new("MQTT client is not connected.", $Connection.Broker)
        }

        $msgBuilder = $Connection.MqttFactory.CreateApplicationMessageBuilder()
        $msg = $msgBuilder.WithTopic($topic).WithPayload($compressed).WithQualityOfServiceLevel(0).Build()
        $Connection.MqttClient.PublishAsync($msg, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null

        # Log command
        $logEntry = [PSCustomObject]@{
            Timestamp = [datetime]::UtcNow
            Command   = $Command
            Direction = 'Sent'
            Topic     = $topic
        }
        $Connection.CommandLog.Add($logEntry)

        if ($NoWait) { return $null }

        # Wait for data_feedback with matching topic
        $deadline = [datetime]::UtcNow.AddMilliseconds($TimeoutMs)
        while ([datetime]::UtcNow -lt $deadline) {
            $response = $null
            if ($Connection.ResponseQueue.TryDequeue([ref]$response)) {
                if ($response.topic -eq $Command) {
                    $result = [YarboCommandResult]::new($response)
                    # Log response
                    $Connection.CommandLog.Add([PSCustomObject]@{
                        Timestamp = [datetime]::UtcNow
                        Command   = $Command
                        Direction = 'Received'
                        State     = $result.State
                        Message   = $result.Message
                    })
                    return $result
                }
                # Not our response — could be for a different command, re-enqueue (edge case)
                Write-Debug (Protect-YarboLogMessage "[Send-MqttCommand] Got feedback for '$($response.topic)' while waiting for '$Command'")
                $Connection.ResponseQueue.Enqueue($response)
            }
            [System.Threading.Thread]::Sleep(50)
        }

        # Timeout
        Write-Debug (Protect-YarboLogMessage "[Send-MqttCommand] Timeout waiting for '$Command' after ${TimeoutMs}ms")
        return $null
    }
    finally {
        $Connection.CommandSemaphore.Release() | Out-Null
    }
}

function Send-MqttFireAndForget {
    <#
    .SYNOPSIS
        Sends an MQTT command without waiting for a response.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter()]
        [hashtable]$Payload = @{}
    )

    $topic = "snowbot/$($Connection.SerialNumber)/app/$Command"
    Write-Verbose (Protect-YarboLogMessage "[Send-MqttFireAndForget] Routing via local MQTT → $topic")

    $compressed = ConvertTo-ZlibPayload -Payload $Payload

    if ($null -eq $Connection.MqttClient) {
        throw [YarboConnectionException]::new("MQTT client is not connected.", $Connection.Broker)
    }

    $msgBuilder = $Connection.MqttFactory.CreateApplicationMessageBuilder()
    $msg = $msgBuilder.WithTopic($topic).WithPayload($compressed).WithQualityOfServiceLevel(0).Build()
    $Connection.MqttClient.PublishAsync($msg, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null

    $Connection.CommandLog.Add([PSCustomObject]@{
        Timestamp = [datetime]::UtcNow
        Command   = $Command
        Direction = 'Sent (fire-and-forget)'
        Topic     = $topic
    })
}
