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

    if ($null -eq $result) {
        Write-Warning ("get_controller timed out for $($Connection.SerialNumber). " +
            "Assuming controller acquired — commands may fail if another client holds the controller. " +
            "Use -NoControllerInit and Send-YarboCommand -Command get_controller to retry manually.")
        $Connection.ControllerAcquired = $true
        return
    }

    if ($result.State -eq 0) {
        $Connection.ControllerAcquired = $true
        $Connection.State = [MqttConnectionState]::ControllerAcquired
        Write-Verbose (Protect-YarboLogMessage "[Assert-YarboController] Controller acquired successfully")
    }
    else {
        throw [YarboCommandException]::new($result)
    }
}
