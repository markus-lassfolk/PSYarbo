function Send-YarboReturnToDock {
    <#
.SYNOPSIS
    Sends the return-to-dock (cmd_recharge) command to the robot.

.DESCRIPTION
    Sends cmd_recharge to instruct the Yarbo robot to stop its current activity and
    navigate back to the charging dock. This is a fire-and-forget command — no
    response is expected from the robot.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Send-YarboReturnToDock

.EXAMPLE
    $conn | Send-YarboReturnToDock -WhatIf

.LINK
    Stop-YarboPlan
    Start-YarboPlan
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [Alias('Return-YarboToDock', 'Start-YarboRecharge')]
    [OutputType([void])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection

        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Return to dock (cmd_recharge)')) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Send-YarboReturnToDock] Routing via local MQTT → cmd_recharge")
            Send-MqttFireAndForget -Connection $conn -Command 'cmd_recharge' -Payload @{}
        }
    }
}
