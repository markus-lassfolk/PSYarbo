function Get-YarboFirmware {
    <#
.SYNOPSIS
    Returns the robot's firmware version information.

.DESCRIPTION
    Queries the robot for current firmware version. With -IncludeLatest, also
    queries the cloud API for the latest available version.

.PARAMETER Connection
    The connection to query. Defaults to the current default.

.PARAMETER IncludeLatest
    Also query the cloud for the latest available firmware version.

.EXAMPLE
    Get-YarboFirmware

.EXAMPLE
    Get-YarboFirmware -IncludeLatest

.LINK
    Get-YarboStatus
    Connect-YarboCloud
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter()]
        [switch]$IncludeLatest
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        $robot = Get-YarboRobot -Connection $conn -Refresh

        $info = [PSCustomObject]@{
            SerialNumber     = $conn.SerialNumber
            HeadType         = $robot.HeadType
            HeadSerialNumber = $robot.HeadSerialNumber
        }

        if ($IncludeLatest -and $script:YarboCloudSession) {
            try {
                $latest = Invoke-YarboCloudApi -Session $script:YarboCloudSession `
                    -Method 'GET' -Path '/yarbo/commonUser/getLatestPubVersion' `
                    -CmdletName 'Get-YarboFirmware'
                $info | Add-Member -NotePropertyName 'LatestVersion' -NotePropertyValue $latest
            } catch {
                Write-Warning "Could not fetch latest firmware version from cloud: $($_.Exception.Message)"
            }
        }

        return $info
    }
}
