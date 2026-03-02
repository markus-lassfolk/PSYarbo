function Set-YarboChargeLimit {
    <#
.SYNOPSIS
    Sets the battery charge limits (min/max percentage).

.DESCRIPTION
    Sends set_charge_limit so the robot returns to dock when battery falls to
    MinPercent and stops charging at MaxPercent. Aligns with python-yarbo
    set_charge_limit(min_pct, max_pct).

.PARAMETER MinPercent
    Minimum charge percentage before the robot returns to dock (e.g. 20).

.PARAMETER MaxPercent
    Maximum charge percentage at which charging stops (e.g. 100).

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboChargeLimit -MinPercent 20 -MaxPercent 100

.LINK
    Get-YarboBattery
    Send-YarboReturnToDock
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(0, 100)]
        [int]$MinPercent,

        [Parameter(Mandatory, Position = 1)]
        [ValidateRange(0, 100)]
        [int]$MaxPercent,

        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set charge limit min=$MinPercent% max=$MaxPercent%")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'set_charge_limit' -Payload @{ min = $MinPercent; max = $MaxPercent }
        }
    }
}
