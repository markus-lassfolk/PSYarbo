function Disconnect-Yarbo {
<#
.SYNOPSIS
    Disconnects from a Yarbo robot's MQTT broker.

.DESCRIPTION
    Cleanly unsubscribes from MQTT topics and disconnects the client.
    Removes the connection from the module's connection store.

.PARAMETER Connection
    The connection to disconnect. Defaults to the current default connection.

.PARAMETER SerialNumber
    Disconnect by serial number.

.PARAMETER All
    Disconnect all active connections.

.EXAMPLE
    Disconnect-Yarbo

.EXAMPLE
    Disconnect-Yarbo -All

.LINK
    Connect-Yarbo
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter()]
        [string]$SerialNumber,

        [Parameter()]
        [switch]$All
    )

    process {
        $connections = @()

        if ($All) {
            $connections = $script:YarboConnections.Values
        }
        elseif ($Connection) {
            $connections = @($Connection)
        }
        elseif ($SerialNumber -and $script:YarboConnections.ContainsKey($SerialNumber)) {
            $connections = @($script:YarboConnections[$SerialNumber])
        }
        elseif ($script:DefaultConnection) {
            $connections = @($script:DefaultConnection)
        }
        else {
            Write-Warning "No active Yarbo connection to disconnect."
            return
        }

        foreach ($conn in $connections) {
            if ($PSCmdlet.ShouldProcess($conn.ToString(), 'Disconnect')) {
                Write-Verbose (Protect-YarboLogMessage "[Disconnect-Yarbo] Disconnecting $conn")
                try {
                    if ($conn.MqttClient -and $conn.MqttClient.IsConnected) {
                        $conn.CancellationSource.Cancel()
                        $conn.MqttClient.DisconnectAsync(
                            $conn.MqttFactory.CreateClientDisconnectOptionsBuilder().Build(),
                            [System.Threading.CancellationToken]::None
                        ).GetAwaiter().GetResult() | Out-Null
                    }
                }
                catch {
                    Write-Warning "Error during disconnect: $($_.Exception.Message)"
                }
                finally {
                    $conn.State = [MqttConnectionState]::Disconnected
                    $conn.ControllerAcquired = $false
                    $script:YarboConnections.Remove($conn.SerialNumber) | Out-Null
                    if ($script:DefaultConnection -eq $conn) {
                        $script:DefaultConnection = $script:YarboConnections.Values | Select-Object -First 1
                    }
                }
            }
        }
    }
}
