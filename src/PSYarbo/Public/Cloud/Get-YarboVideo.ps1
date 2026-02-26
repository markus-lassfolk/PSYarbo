function Get-YarboVideo {
    <#
.SYNOPSIS
    Gets an Agora RTC token for live video streaming.

.DESCRIPTION
    Requests a video streaming token from the Yarbo cloud.

.PARAMETER SerialNumber
    The robot's serial number.

.PARAMETER ChannelName
    Video channel name. Default: 'psyarbo-video'.

.PARAMETER Session
    The cloud session to use. Defaults to the current session.

.EXAMPLE
    Get-YarboVideo -SerialNumber 24400102L8HO5227

.LINK
    Connect-YarboCloud
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboCloudSession]$Session,

        [Parameter(Mandatory)]
        [string]$SerialNumber,

        [Parameter()]
        [string]$ChannelName = 'psyarbo-video'
    )

    process {
        $s = if ($Session) { $Session } elseif ($script:YarboCloudSession) { $script:YarboCloudSession }
        else { throw [YarboCloudAuthException]::new("No cloud session. Use Connect-YarboCloud first.", 'NO_SESSION') }

        return Invoke-YarboCloudApi -Session $s -Method 'POST' `
            -Path '/yarbo/robot-service/robot/commonUser/getAgoraToken' `
            -Body @{ sn = $SerialNumber; channel_name = $ChannelName } `
            -CmdletName 'Get-YarboVideo'
    }
}
