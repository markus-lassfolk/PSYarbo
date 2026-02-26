function Get-YarboNotificationSetting {
    <#
.SYNOPSIS
    Retrieves push notification preferences from the Yarbo cloud.

.DESCRIPTION
    Fetches the current notification settings for the authenticated account.
    Returns an object with MobileSystemNotification, GeneralNotification,
    and ErrNotification flags (1=enabled, 0=disabled).

.PARAMETER Session
    The cloud session to use. Defaults to the current session.

.EXAMPLE
    Get-YarboNotificationSetting

.LINK
    Connect-YarboCloud
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboCloudSession]$Session
    )

    process {
        $s = if ($Session) { $Session } elseif ($script:YarboCloudSession) { $script:YarboCloudSession }
        else { throw [YarboCloudAuthException]::new("No cloud session. Use Connect-YarboCloud first.", 'NO_SESSION') }

        return Invoke-YarboCloudApi -Session $s -Method 'GET' `
            -Path '/yarbo/msg/getNotificationSetting' `
            -CmdletName 'Get-YarboNotificationSetting'
    }
}
