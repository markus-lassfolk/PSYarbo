function Get-YarboDeviceMessage {
    <#
.SYNOPSIS
    Retrieves device-level alert messages from the Yarbo cloud.

.DESCRIPTION
    Fetches the cloud message feed for device alerts associated with
    the authenticated account (e.g. low battery, error notifications).

.PARAMETER SerialNumber
    Optional serial number to filter messages for a specific robot.
    When omitted, all device messages are returned.

.PARAMETER Session
    The cloud session to use. Defaults to the current session.

.EXAMPLE
    Get-YarboDeviceMessage

.EXAMPLE
    Get-YarboDeviceMessage -SerialNumber '24400102L8HO5227'

.LINK
    Connect-YarboCloud
    Get-YarboDevice
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$SerialNumber,

        [Parameter(ValueFromPipeline)]
        [YarboCloudSession]$Session
    )

    process {
        $s = if ($Session) { $Session } elseif ($script:YarboCloudSession) { $script:YarboCloudSession }
        else { throw [YarboCloudAuthException]::new("No cloud session. Use Connect-YarboCloud first.", 'NO_SESSION') }

        $data = Invoke-YarboCloudApi -Session $s -Method 'GET' `
            -Path '/yarbo/msg/userDeviceMsg' `
            -CmdletName 'Get-YarboDeviceMessage'

        $messages = if ($data -and $data.deviceMsg) { $data.deviceMsg } else { @() }

        if ($SerialNumber) {
            $messages = $messages | Where-Object { $_.sn -eq $SerialNumber }
        }

        return $messages
    }
}
