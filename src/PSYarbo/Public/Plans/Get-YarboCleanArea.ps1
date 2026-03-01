function Get-YarboCleanArea {
    <#
.SYNOPSIS
    Retrieves the robot's clean/work area configuration.

.DESCRIPTION
    Sends read_clean_area and returns the data feedback response containing
    the configured work area boundaries.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboCleanArea

.EXAMPLE
    Get-YarboCleanArea | ConvertTo-Json -Depth 5

.LINK
    Get-YarboMap
    Get-YarboRechargePoint
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboCleanArea] Routing via local MQTT → read_clean_area")
        $result = Send-MqttCommand -Connection $conn -Command 'read_clean_area' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "read_clean_area failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.ReadCleanArea' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
