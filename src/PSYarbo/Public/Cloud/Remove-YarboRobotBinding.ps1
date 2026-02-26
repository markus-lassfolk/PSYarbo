function Remove-YarboRobotBinding {
    <#
.SYNOPSIS
    Unbinds one or more robots from the current Yarbo cloud account.

.DESCRIPTION
    Sends an unbind request to the cloud REST API to remove the association
    between the specified robot serial numbers and the authenticated account.

.PARAMETER SerialNumber
    One or more serial numbers of robots to unbind.

.PARAMETER Session
    The cloud session to use. Defaults to the current session.

.EXAMPLE
    Remove-YarboRobotBinding -SerialNumber '24400102L8HO5227'

.EXAMPLE
    Remove-YarboRobotBinding -SerialNumber 'SN001','SN002'

.LINK
    Connect-YarboCloud
    Add-YarboRobotBinding
    Get-YarboDevice
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$SerialNumber,

        [Parameter()]
        [YarboCloudSession]$Session
    )

    process {
        $s = if ($Session) { $Session } elseif ($script:YarboCloudSession) { $script:YarboCloudSession }
        else { throw [YarboCloudAuthException]::new("No cloud session. Use Connect-YarboCloud first.", 'NO_SESSION') }

        $label = $SerialNumber -join ', '
        if ($PSCmdlet.ShouldProcess($label, 'Unbind robots from cloud account')) {
            Invoke-YarboCloudApi -Session $s -Method 'POST' `
                -Path '/yarbo/robot-service/commonUser/userRobotBind/unbind' `
                -Body @{ serialNums = $SerialNumber } `
                -CmdletName 'Remove-YarboRobotBinding' | Out-Null
        }
    }
}
