function Start-YarboRecharge {
    <#
.SYNOPSIS
    Sends the robot to its charging station.

.DESCRIPTION
    Sends cmd_recharge to instruct the robot to navigate back to its
    docking/charging point.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Start-YarboRecharge

.LINK
    Save-YarboChargingPoint
    Get-YarboRechargePoint
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Return to charge (cmd_recharge)')) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Start-YarboRecharge] Routing via local MQTT → cmd_recharge")
            Send-MqttFireAndForget -Connection $conn -Command 'cmd_recharge' -Payload @{}
        }
    }
}
