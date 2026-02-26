function Get-YarboStatus {
<#
.SYNOPSIS
    Returns comprehensive robot status.

.DESCRIPTION
    Sends get_device_msg and parses the full DeviceMSG response into a YarboRobot object.

.PARAMETER Connection
    The connection to query. Defaults to the current default.

.EXAMPLE
    Get-YarboStatus

.EXAMPLE
    Connect-Yarbo -Broker 192.168.1.24 -SerialNumber 24400102L8HO5227 | Get-YarboStatus

.LINK
    Get-YarboRobot
    Get-YarboBattery
#>
    [CmdletBinding()]
    [OutputType([YarboRobot])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboStatus] Routing via local MQTT → get_device_msg")

        $result = Send-MqttCommand -Connection $conn -Command 'get_device_msg' -Payload @{} -TimeoutMs 5000

        if ($result.TimedOut) {
            $PSCmdlet.WriteError((New-YarboError `
                -Message "Timed out waiting for device message. Verify the robot is powered on and the MQTT broker at $($conn.Broker):$($conn.Port) is reachable." `
                -ErrorId 'PSYarbo.Timeout.GetDeviceMsg' `
                -Category 'OperationTimeout' `
                -TargetObject $conn `
                -Exception ([YarboTimeoutException]::new('get_device_msg', 5000))))
            return
        }

        if (-not $result.Success) {
            $PSCmdlet.WriteError((New-YarboError `
                -Message "get_device_msg failed: $($result.Message). Check robot state or reconnect." `
                -ErrorId 'PSYarbo.CommandFailed.GetDeviceMsg' `
                -Category 'InvalidResult' `
                -TargetObject $result))
            return
        }

        $robot = ConvertTo-YarboRobot -DeviceMsg $result.Data -SerialNumber $conn.SerialNumber -Broker $conn.Broker -Port $conn.Port
        $conn.Robot = $robot
        return $robot
    }
}
