<#
.SYNOPSIS
    Mock MQTT client and YarboConnection factory for unit tests (§8.3).
.DESCRIPTION
    Provides New-MockYarboConnection which creates a YarboConnection wired
    to an in-memory fake MQTT client (duck-typed; no real IMqttClient). Tests can:
      - Inspect published messages via $conn.__PublishedMessages
      - Simulate responses via Push-MockCommandResponse (topic → payload)
      - Simulate push telemetry via Push-MockTelemetryEvent
    No network connection is required.
#>

#region Helper: build a YarboConnection without a real MQTT client

function New-MockYarboConnection {
    <#
    .SYNOPSIS
        Creates a YarboConnection pre-wired for unit testing (no MQTT network).
    .PARAMETER SerialNumber
        Robot serial number to assign. Default: 'TEST-SN'.
    .PARAMETER Broker
        Broker IP to assign. Default: '127.0.0.1'.
    .PARAMETER Port
        Port to assign. Default: 1883.
    #>
    param(
        [string]$SerialNumber = 'TEST-SN',
        [string]$Broker       = '127.0.0.1',
        [int]   $Port         = 1883
    )

    $conn = [YarboConnection]::new()
    $conn.SerialNumber = $SerialNumber
    $conn.Broker       = $Broker
    $conn.Port         = $Port
    $conn.State        = [MqttConnectionState]::ControllerAcquired
    $conn.ControllerAcquired = $true

    # Attach a list to capture "published" messages so tests can assert on them
    $conn | Add-Member -NotePropertyName '__PublishedMessages' -NotePropertyValue ([System.Collections.Generic.List[PSCustomObject]]::new())

    return $conn
}

function Push-MockTelemetryEvent {
    <#
    .SYNOPSIS
        Simulates the robot pushing a DeviceMSG/HeartBeat/PlanFeedback event.
    .PARAMETER Connection
        The mock YarboConnection.
    .PARAMETER MessageType
        One of: DeviceMSG, HeartBeat, PlanFeedback, RechargeFeedback.
    .PARAMETER Data
        The decoded payload as PSCustomObject.
    #>
    param(
        [Parameter(Mandatory)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory)]
        [ValidateSet('DeviceMSG', 'HeartBeat', 'PlanFeedback', 'RechargeFeedback')]
        [string]$MessageType,

        [Parameter(Mandatory)]
        [PSCustomObject]$Data
    )

    $event = [PSCustomObject]@{
        MessageType = $MessageType
        Timestamp   = [datetime]::UtcNow
        Data        = $Data
    }
    $Connection.TelemetryQueue.Enqueue($event)
    $Connection.TelemetrySignal.Release() | Out-Null
}

function Push-MockCommandResponse {
    <#
    .SYNOPSIS
        Simulates the robot responding to a command via data_feedback.
    .PARAMETER Connection
        The mock YarboConnection.
    .PARAMETER Topic
        The command topic that was sent (e.g., 'get_device_msg').
    .PARAMETER State
        Response state code (0 = success).
    .PARAMETER Data
        Optional response data.
    #>
    param(
        [Parameter(Mandatory)]
        [YarboConnection]$Connection,

        [Parameter(Mandatory)]
        [string]$Topic,

        [int]$State = 0,

        [PSCustomObject]$Data = $null
    )

    $response = [PSCustomObject]@{
        topic = $Topic
        state = $State
        msg   = if ($State -eq 0) { 'success' } else { 'error' }
        data  = $Data
    }
    $Connection.ResponseQueue.Enqueue($response)
    $Connection.ResponseSignal.Release() | Out-Null
}

#endregion
