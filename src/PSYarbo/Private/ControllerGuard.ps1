function Assert-YarboController {
    <#
    .SYNOPSIS
        Ensures get_controller has been sent for this connection.
        Sends it automatically if not yet acquired.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [YarboConnection]$Connection
    )

    if ($Connection.ControllerAcquired) {
        Write-Verbose (Protect-YarboLogMessage "[Assert-YarboController] Controller already acquired for $($Connection.SerialNumber)")
        return
    }

    Write-Verbose (Protect-YarboLogMessage "[Assert-YarboController] Acquiring controller for $($Connection.SerialNumber)...")
    $result = Send-MqttCommand -Connection $Connection -Command 'get_controller' -Payload @{} -TimeoutMs 5000

    if ($result.TimedOut) {
        # Do NOT set ControllerAcquired=true on timeout — leave it false so callers can retry.
        # Throw so the caller (Connect-Yarbo / Assert-YarboController usage sites) can decide how to handle.
        throw [YarboTimeoutException]::new('get_controller', 5000)
    }

    if ($result.State -eq 0) {
        $Connection.ControllerAcquired = $true
        $Connection.State = [MqttConnectionState]::ControllerAcquired
        Write-Verbose (Protect-YarboLogMessage "[Assert-YarboController] Controller acquired successfully")
    } else {
        throw [YarboCommandException]::new($result)
    }
}
