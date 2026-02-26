function Get-YarboDevice {
<#
.SYNOPSIS
    Lists robots bound to your Yarbo cloud account.

.DESCRIPTION
    Queries the cloud API for all robots associated with your account.

.PARAMETER Session
    The cloud session to use. Defaults to the current session.

.EXAMPLE
    Get-YarboDevice

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

        $data = Invoke-YarboCloudApi -Session $s -Method 'GET' `
            -Path '/yarbo/robot-service/commonUser/userRobotBind/getUserRobotBindVos' `
            -CmdletName 'Get-YarboDevice'

        return $data.deviceList
    }
}
