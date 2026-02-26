function Connect-Yarbo {
    <#
.SYNOPSIS
    Establishes a local MQTT connection to a Yarbo robot.

.DESCRIPTION
    Connects to a Yarbo robot's local EMQX MQTT broker (anonymous, port 1883).
    Subscribes to all device telemetry topics and optionally acquires controller
    status via get_controller.

.PARAMETER Broker
    IP address or hostname of the robot's MQTT broker.

.PARAMETER SerialNumber
    The robot's serial number (e.g., 24400102L8HO5227).

.PARAMETER Port
    MQTT broker port. Defaults to 1883.

.PARAMETER Robot
    A YarboRobot object from Find-Yarbo (pipeline input).

.PARAMETER ClientId
    MQTT client identifier. Auto-generated if not specified.

.PARAMETER NoControllerInit
    Skip the automatic get_controller command during connection.

.PARAMETER PassThru
    Return the connection object (also returned by default).

.EXAMPLE
    Connect-Yarbo -Broker 192.168.1.24 -SerialNumber 24400102L8HO5227

.EXAMPLE
    Find-Yarbo | Connect-Yarbo

.LINK
    Disconnect-Yarbo
    Find-Yarbo
    about_PSYarbo_MQTT
#>
    [CmdletBinding(DefaultParameterSetName = 'Direct')]
    [OutputType([YarboConnection])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Direct', Position = 0,
            ValueFromPipelineByPropertyName)]
        [string]$Broker,

        [Parameter(Mandatory, ParameterSetName = 'Direct', Position = 1,
            ValueFromPipelineByPropertyName)]
        [string]$SerialNumber,

        [Parameter(ParameterSetName = 'Direct', ValueFromPipelineByPropertyName)]
        [Nullable[int]]$Port,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Pipeline')]
        [YarboRobot]$Robot,

        [Parameter()]
        [string]$ClientId,

        [Parameter()]
        [switch]$NoControllerInit,

        [Parameter()]
        [int]$TimeoutSeconds = 10,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Pipeline') {
            $Broker = $Robot.Broker
            $SerialNumber = $Robot.SerialNumber
            $Port = if ($Robot.Port) { $Robot.Port } else { $null }
        }

        # Resolve defaults from environment
        if (-not $Broker -and $env:YARBO_BROKER) { $Broker = $env:YARBO_BROKER }
        if (-not $SerialNumber -and $env:YARBO_SN) { $SerialNumber = $env:YARBO_SN }
        if (-not $Port -and $env:YARBO_PORT) { $Port = [int]$env:YARBO_PORT }
        
        # Apply final default for Port
        if (-not $Port) { $Port = 1883 }

        # Generate unique ClientId per pipeline iteration if not provided
        if (-not $ClientId) {
            $ClientId = "PSYarbo-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        }

        $conn = [YarboConnection]::new()
        $conn.Broker = $Broker
        $conn.Port = $Port
        $conn.SerialNumber = $SerialNumber
        $conn.ClientId = $ClientId
        $conn.State = [MqttConnectionState]::Connecting

        Write-Verbose (Protect-YarboLogMessage "[Connect-Yarbo] Connecting to ${Broker}:${Port} as $ClientId")

        try {
            # Create MQTTnet factory and client
            $factory = $script:MqttAssembly.GetType('MQTTnet.MqttFactory')
            $conn.MqttFactory = [System.Activator]::CreateInstance($factory)
            $conn.MqttClient = $conn.MqttFactory.CreateMqttClient()

            # Build connection options
            $optionsBuilder = $conn.MqttFactory.CreateClientOptionsBuilder()
            $options = $optionsBuilder.WithTcpServer($Broker, $Port).WithClientId($ClientId).WithTimeout(
                [TimeSpan]::FromSeconds($TimeoutSeconds)
            ).Build()

            # Connect
            $conn.MqttClient.ConnectAsync($options, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
            $conn.State = [MqttConnectionState]::Connected
            $conn.ConnectedAt = [datetime]::UtcNow

            Write-Verbose (Protect-YarboLogMessage "[Connect-Yarbo] Connected to ${Broker}:${Port}. Subscribing to snowbot/$SerialNumber/device/#")

            # Subscribe to all device topics
            $subBuilder = $conn.MqttFactory.CreateSubscribeOptionsBuilder()
            $subOptions = $subBuilder.WithTopicFilter("snowbot/$SerialNumber/device/#").Build()
            $conn.MqttClient.SubscribeAsync($subOptions, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null

            # Set up message handler for routing responses
            $conn.MqttClient.ApplicationMessageReceivedAsync.Add({
                    param($args)
                    $topic = $args.ApplicationMessage.Topic
                    $payload = $args.ApplicationMessage.PayloadSegment.ToArray()

                    # Guard: skip empty/null payloads
                    if ($null -eq $payload -or $payload.Length -eq 0) {
                        return [System.Threading.Tasks.Task]::CompletedTask
                    }

                    if ($topic -like '*/device/data_feedback') {
                        $decoded = ConvertFrom-ZlibPayload -Data $payload
                        if ($decoded) {
                            $conn.ResponseQueue.Enqueue($decoded)
                            $conn.ResponseSignal.Release() | Out-Null  # Wake Send-MqttCommand waiter
                        }
                    } elseif ($topic -like '*/device/heart_beat') {
                        $decoded = ConvertFrom-ZlibPayload -Data $payload
                        if ($decoded) {
                            $conn.LastHeartbeat = [datetime]::UtcNow
                            $conn.LastWorkingState = [int]($decoded.working_state)
                            # Reset controller on sleep
                            if ($decoded.working_state -eq 0 -and $conn.ControllerAcquired) {
                                $conn.ControllerAcquired = $false
                                $conn.State = [MqttConnectionState]::Connected
                            }
                        }
                    } elseif ($topic -like '*/device/DeviceMSG') {
                        $decoded = ConvertFrom-ZlibPayload -Data $payload
                        if ($decoded) {
                            $conn.Robot = ConvertTo-YarboRobot -DeviceMsg $decoded -SerialNumber $conn.SerialNumber -Broker $conn.Broker -Port $conn.Port
                        }
                    }

                    return [System.Threading.Tasks.Task]::CompletedTask
                }.GetNewClosure())

            # Acquire controller unless skipped
            if (-not $NoControllerInit) {
                Assert-YarboController -Connection $conn
            }
        } catch {
            $conn.State = [MqttConnectionState]::Disconnected
            if ($conn.MqttClient) {
                try {
                    $conn.MqttClient.DisconnectAsync([System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
                } catch {
                    Write-Debug "MQTT cleanup error (non-fatal): $($_.Exception.Message)"
                }
                try {
                    $conn.MqttClient.Dispose()
                } catch {
                    Write-Debug "MQTT cleanup error (non-fatal): $($_.Exception.Message)"
                }
            }
            if ($_.Exception -is [YarboException]) { throw }
            throw [YarboConnectionException]::new(
                "Failed to connect to MQTT broker at ${Broker}:${Port}: $($_.Exception.Message)",
                $Broker
            )
        }

        # Store in module state
        $script:YarboConnections[$SerialNumber] = $conn
        $script:DefaultConnection = $conn

        Write-Verbose (Protect-YarboLogMessage "[Connect-Yarbo] Connection established: $conn")
        return $conn
    }
}
