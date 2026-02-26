function Get-YarboTelemetry {
<#
.SYNOPSIS
    Retrieves a single telemetry snapshot.

.DESCRIPTION
    Sends get_device_msg and parses the response into a YarboTelemetry object.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboTelemetry

.LINK
    Watch-YarboTelemetry
    Export-YarboTelemetry
#>
    [CmdletBinding()]
    [OutputType([YarboTelemetry])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboTelemetry] Routing via local MQTT → get_device_msg")
        $result = Send-MqttCommand -Connection $conn -Command 'get_device_msg' -Payload @{}

        if ($null -eq $result) {
            $PSCmdlet.WriteError((New-YarboError -Message "Timed out waiting for telemetry." -ErrorId 'PSYarbo.Timeout.GetTelemetry' -Category 'OperationTimeout'))
            return
        }

        if ($result.Success -and $result.Data) {
            return ConvertTo-YarboTelemetry -DeviceMsg $result.Data -SerialNumber $conn.SerialNumber
        }
    }
}
