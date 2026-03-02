function Get-YarboCameraStatus {
    <#
.SYNOPSIS
    Gets the camera status (check_camera_status).
.EXAMPLE
    Get-YarboCameraStatus
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )
    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        $result = Send-MqttCommand -Connection $conn -Command 'check_camera_status' -Payload @{}
        if ($null -eq $result -or -not $result.Success) { return }
        return $result.Data
    }
}
