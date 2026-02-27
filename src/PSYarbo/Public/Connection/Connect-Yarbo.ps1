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
    Connect-Yarbo -Broker <rover-ip> -SerialNumber <serial-number>

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

        # Resolve defaults via ConfigManager (env vars + config file + built-in defaults)
        $cfg = Get-YarboConfig -Overrides @{
            Broker = $Broker
            SN     = $SerialNumber
            Port   = if ($Port) { $Port } else { $null }
        }
        if (-not $Broker) { $Broker = $cfg['Broker'] }
        if (-not $SerialNumber) { $SerialNumber = $cfg['SN'] }
        if (-not $Port) { $Port = $cfg['Port'] }

        # Generate unique ClientId per pipeline iteration if not provided
        $effectiveClientId = if ($ClientId) { $ClientId } else { "PSYarbo-$([guid]::NewGuid().ToString('N').Substring(0,8))" }

        $conn = [YarboConnection]::new()
        $conn.Broker = $Broker
        $conn.Port = $Port
        $conn.SerialNumber = $SerialNumber
        $conn.ClientId = $effectiveClientId
        $conn.State = [MqttConnectionState]::Connecting

        Write-Verbose (Protect-YarboLogMessage "[Connect-Yarbo] Connecting to ${Broker}:${Port} as $effectiveClientId")

        try {
            # Guard: MQTTnet assembly must be loaded before any connection attempt
            if ($null -eq $script:MqttAssembly) {
                throw [YarboConnectionException]::new(
                    "MQTTnet assembly is not loaded. Run 'build/Install-Dependencies.ps1' to install it, then restart your PowerShell session.",
                    $Broker
                )
            }

            # Create MQTTnet factory and client
            $factory = $script:MqttAssembly.GetType('MQTTnet.MqttFactory')
            $conn.MqttFactory = [System.Activator]::CreateInstance($factory)
            $conn.MqttClient = $conn.MqttFactory.CreateMqttClient()

            # Attach message handler before connecting (MQTTnet requirement)
            $callback = [Func[object, System.Threading.Tasks.Task]] {
                param($args)
                $topic = $args.ApplicationMessage.Topic
                $payload = $args.ApplicationMessage.PayloadSegment.ToArray()

                if ($null -eq $payload -or $payload.Length -eq 0) {
                    return [System.Threading.Tasks.Task]::CompletedTask
                }

                if ($topic -like '*/device/data_feedback') {
                    $decoded = ConvertFrom-ZlibPayload -Data $payload
                    if ($decoded) {
                        $conn.ResponseQueue.Enqueue($decoded)
                        $conn.ResponseSignal.Release() | Out-Null
                    }
                } elseif ($topic -like '*/device/heart_beat') {
                    $decoded = ConvertFrom-ZlibPayload -Data $payload
                    if ($decoded) {
                        $conn.LastHeartbeat = [datetime]::UtcNow
                        $conn.LastWorkingState = [int]($decoded.working_state)
                        if ($decoded.working_state -eq 0 -and $conn.ControllerAcquired) {
                            $conn.ControllerAcquired = $false
                            $conn.State = [MqttConnectionState]::Connected
                        }
                        $conn.TelemetryQueue.Enqueue([PSCustomObject]@{
                                MessageType = 'HeartBeat'
                                Timestamp   = [datetime]::UtcNow
                                Data        = $decoded
                            })
                        $conn.TelemetrySignal.Release() | Out-Null
                    }
                } elseif ($topic -like '*/device/DeviceMSG') {
                    $decoded = ConvertFrom-ZlibPayload -Data $payload
                    if ($decoded) {
                        $conn.Robot = ConvertTo-YarboRobot -DeviceMsg $decoded -SerialNumber $conn.SerialNumber -Broker $conn.Broker -Port $conn.Port
                        $conn.TelemetryQueue.Enqueue([PSCustomObject]@{
                                MessageType = 'DeviceMSG'
                                Timestamp   = [datetime]::UtcNow
                                Data        = $decoded
                            })
                        $conn.TelemetrySignal.Release() | Out-Null
                        $conn.TelemetryLog.Enqueue([PSCustomObject]@{
                                Timestamp   = [datetime]::UtcNow
                                MessageType = 'DeviceMSG'
                                Direction   = 'Pushed'
                                Topic       = $topic
                            })
                        if ($conn.TelemetryLog.Count -gt 200) {
                            $discard = $null
                            $conn.TelemetryLog.TryDequeue([ref]$discard) | Out-Null
                        }
                    }
                } elseif ($topic -like '*/device/plan_feedback') {
                    $decoded = ConvertFrom-ZlibPayload -Data $payload
                    if ($decoded) {
                        $conn.LastPlanFeedback = $decoded
                        $conn.TelemetryQueue.Enqueue([PSCustomObject]@{
                                MessageType = 'PlanFeedback'
                                Timestamp   = [datetime]::UtcNow
                                Data        = $decoded
                            })
                        $conn.TelemetrySignal.Release() | Out-Null
                        $conn.TelemetryLog.Enqueue([PSCustomObject]@{
                                Timestamp   = [datetime]::UtcNow
                                MessageType = 'PlanFeedback'
                                Direction   = 'Pushed'
                                Topic       = $topic
                            })
                        if ($conn.TelemetryLog.Count -gt 200) {
                            $discard = $null
                            $conn.TelemetryLog.TryDequeue([ref]$discard) | Out-Null
                        }
                    }
                } elseif ($topic -like '*/device/recharge_feedback') {
                    $decoded = ConvertFrom-ZlibPayload -Data $payload
                    if ($decoded) {
                        $conn.LastRechargeFeedback = $decoded
                        $conn.TelemetryQueue.Enqueue([PSCustomObject]@{
                                MessageType = 'RechargeFeedback'
                                Timestamp   = [datetime]::UtcNow
                                Data        = $decoded
                            })
                        $conn.TelemetrySignal.Release() | Out-Null
                        $conn.TelemetryLog.Enqueue([PSCustomObject]@{
                                Timestamp   = [datetime]::UtcNow
                                MessageType = 'RechargeFeedback'
                                Direction   = 'Pushed'
                                Topic       = $topic
                            })
                        if ($conn.TelemetryLog.Count -gt 200) {
                            $discard = $null
                            $conn.TelemetryLog.TryDequeue([ref]$discard) | Out-Null
                        }
                    }
                }

                return [System.Threading.Tasks.Task]::CompletedTask
            }.GetNewClosure()
            [PSYarbo.Mqtt.MessageReceivedAdapter]::RegisterCallback($conn.MqttClient, $callback)
            $handlerDelegate = [PSYarbo.Mqtt.MessageReceivedAdapter]::GetHandler($conn.MqttClient)
            $conn.MqttClient.GetType().GetMethod('add_ApplicationMessageReceivedAsync').Invoke($conn.MqttClient, @($handlerDelegate)) | Out-Null

            # Build connection options and connect
            $optionsBuilder = $conn.MqttFactory.CreateClientOptionsBuilder()
            $options = $optionsBuilder.WithTcpServer($Broker, $Port).WithClientId($effectiveClientId).WithTimeout(
                [TimeSpan]::FromSeconds($TimeoutSeconds)
            ).Build()

            $conn.MqttClient.ConnectAsync($options, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
            $conn.State = [MqttConnectionState]::Connected
            $conn.ConnectedAt = [datetime]::UtcNow

            Write-Verbose (Protect-YarboLogMessage "[Connect-Yarbo] Connected to ${Broker}:${Port}. Subscribing to snowbot/$SerialNumber/device/#")

            # Subscribe to all device topics
            $subBuilder = $conn.MqttFactory.CreateSubscribeOptionsBuilder()
            $subOptions = $subBuilder.WithTopicFilter("snowbot/$SerialNumber/device/#").Build()
            $conn.MqttClient.SubscribeAsync($subOptions, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null

            # Acquire controller unless skipped
            if (-not $NoControllerInit) {
                try {
                    Assert-YarboController -Connection $conn
                } catch [YarboTimeoutException] {
                    Write-Warning "Controller acquisition timed out (robot may be sleeping). Connection established without controller; use Resume-Yarbo to wake the robot."
                } catch [YarboCommandException] {
                    Write-Warning "Controller acquisition rejected (state $($_.Exception.State)): $($_.Exception.Message). Connection established without controller; another client may hold the controller."
                }
            }
        } catch {
            $originalError = $_
            $conn.State = [MqttConnectionState]::Disconnected
            if ($conn.MqttClient) {
                try {
                    $conn.MqttClient.DisconnectAsync([System.Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
                } catch {
                    Write-Debug "MQTT cleanup error (non-fatal): $($_.Exception.Message)"
                }
            }
            $conn.Dispose()
            if ($originalError.Exception -is [YarboException]) { throw }
            throw [YarboConnectionException]::new(
                "Failed to connect to MQTT broker at ${Broker}:${Port}: $($originalError.Exception.Message)",
                $Broker
            )
        }

        # Dispose any existing connection for this serial number before overwriting
        if ($script:YarboConnections.ContainsKey($SerialNumber)) {
            $script:YarboConnections[$SerialNumber].Dispose()
        }

        # Store in module state
        $script:YarboConnections[$SerialNumber] = $conn
        $script:DefaultConnection = $conn

        Write-Verbose (Protect-YarboLogMessage "[Connect-Yarbo] Connection established: $conn")
        return $conn
    }
}
