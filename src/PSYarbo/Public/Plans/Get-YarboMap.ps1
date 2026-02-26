function Get-YarboMap {
<#
.SYNOPSIS
    Retrieves the robot's map data.

.DESCRIPTION
    Sends get_map and returns the raw map data. Optionally saves to a file.

.PARAMETER OutputPath
    Path to save the raw map data.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboMap

.EXAMPLE
    Get-YarboMap -OutputPath ./map-data.json

.LINK
    Get-YarboPlan
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter()]
        [string]$OutputPath
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboMap] Routing via local MQTT → get_map")
        $result = Send-MqttCommand -Connection $conn -Command 'get_map' -Payload @{} -TimeoutMs 10000

        if ($null -eq $result) {
            $PSCmdlet.WriteError((New-YarboError -Message "get_map timed out." -ErrorId 'PSYarbo.Timeout.GetMap' -Category 'OperationTimeout'))
            return
        }

        if ($OutputPath -and $result.Data) {
            $result.Data | ConvertTo-Json -Depth 20 | Set-Content -Path $OutputPath -Encoding UTF8
            Write-Verbose "[Get-YarboMap] Map data saved to $OutputPath"
        }

        return $result.Data
    }
}
