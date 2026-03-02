function Resume-YarboPlan {
    <#
.SYNOPSIS
    Resumes a paused plan.

.DESCRIPTION
    Sends the resume_plan command to continue a paused plan. Aligns with python-yarbo.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Resume-YarboPlan

.LINK
    Suspend-YarboPlan
    Start-YarboPlan
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Resume plan')) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'resume_plan' -Payload @{}
        }
    }
}
