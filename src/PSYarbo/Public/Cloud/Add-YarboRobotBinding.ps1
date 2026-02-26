function Add-YarboRobotBinding {
    <#
.SYNOPSIS
    Binds a robot to the current Yarbo cloud account.

.DESCRIPTION
    Sends a bindUserRobot request to the cloud REST API to associate
    the specified robot serial number with the authenticated account.

.PARAMETER SerialNumber
    The serial number of the robot to bind.

.PARAMETER Session
    The cloud session to use. Defaults to the current session.

.EXAMPLE
    Add-YarboRobotBinding -SerialNumber '24400102L8HO5227'

.LINK
    Connect-YarboCloud
    Remove-YarboRobotBinding
    Get-YarboDevice
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$SerialNumber,

        [Parameter()]
        [YarboCloudSession]$Session
    )

    process {
        $s = if ($Session) { $Session } elseif ($script:YarboCloudSession) { $script:YarboCloudSession }
        else { throw [YarboCloudAuthException]::new("No cloud session. Use Connect-YarboCloud first.", 'NO_SESSION') }

        if ($PSCmdlet.ShouldProcess($SerialNumber, 'Bind robot to cloud account')) {
            return Invoke-YarboCloudApi -Session $s -Method 'POST' `
                -Path '/yarbo/robot-service/robot/commonUser/bindUserRobot' `
                -Body @{ sn = $SerialNumber } `
                -CmdletName 'Add-YarboRobotBinding'
        }
    }
}
