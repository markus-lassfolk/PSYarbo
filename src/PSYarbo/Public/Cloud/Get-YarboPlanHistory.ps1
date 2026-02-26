function Get-YarboPlanHistory {
<#
.SYNOPSIS
    Retrieves plan execution history from the cloud.

.DESCRIPTION
    Queries the cloud API for plan run history. Falls back to MQTT if
    the cloud endpoint requires SigV4 auth.

.PARAMETER SerialNumber
    The robot's serial number.

.PARAMETER Session
    The cloud session to use. Defaults to the current session.

.EXAMPLE
    Get-YarboPlanHistory -SerialNumber 24400102L8HO5227

.LINK
    Get-YarboPlan
    Connect-YarboCloud
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboCloudSession]$Session,

        [Parameter(Mandatory)]
        [string]$SerialNumber
    )

    process {
        $s = if ($Session) { $Session } elseif ($script:YarboCloudSession) { $script:YarboCloudSession }
             else { throw [YarboCloudAuthException]::new("No cloud session. Use Connect-YarboCloud first.", 'NO_SESSION') }

        try {
            return Invoke-YarboCloudApi -Session $s -Method 'GET' `
                -Path "/yarbo/robot-service/commonUser/robot/getPlanHistoryBySn?sn=$SerialNumber" `
                -CmdletName 'Get-YarboPlanHistory'
        }
        catch {
            Write-Warning "Cloud plan history endpoint may require SigV4 auth. Falling back to MQTT."
            # Try MQTT fallback if connected
            if ($script:YarboConnections.ContainsKey($SerialNumber)) {
                $conn = $script:YarboConnections[$SerialNumber]
                $result = Send-MqttCommand -Connection $conn -Command 'get_plan_history' -Payload @{}
                if ($result -and $result.Success) { return $result.Data }
            }
            throw
        }
    }
}
