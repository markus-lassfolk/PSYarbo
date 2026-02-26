function Set-YarboRobotName {
    <#
.SYNOPSIS
    Renames a robot in the Yarbo cloud.

.DESCRIPTION
    Sends an updateSnowbotName request to the cloud REST API to change
    the display name of the specified robot.

.PARAMETER SerialNumber
    The serial number of the robot to rename.

.PARAMETER Name
    The new display name for the robot.

.PARAMETER Session
    The cloud session to use. Defaults to the current session.

.EXAMPLE
    Set-YarboRobotName -SerialNumber '24400102L8HO5227' -Name 'Front Yard Bot'

.LINK
    Connect-YarboCloud
    Get-YarboDevice
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$SerialNumber,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(ValueFromPipeline)]
        [YarboCloudSession]$Session
    )

    process {
        $s = if ($Session) { $Session } elseif ($script:YarboCloudSession) { $script:YarboCloudSession }
        else { throw [YarboCloudAuthException]::new("No cloud session. Use Connect-YarboCloud first.", 'NO_SESSION') }

        if ($PSCmdlet.ShouldProcess($SerialNumber, "Rename robot to '$Name'")) {
            return Invoke-YarboCloudApi -Session $s -Method 'POST' `
                -Path '/yarbo/robot-service/robot/commonUser/updateSnowbotName' `
                -Body @{ sn = $SerialNumber; name = $Name } `
                -CmdletName 'Set-YarboRobotName'
        }
    }
}
