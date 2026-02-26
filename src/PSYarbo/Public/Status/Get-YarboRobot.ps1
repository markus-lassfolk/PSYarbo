function Get-YarboRobot {
<#
.SYNOPSIS
    Returns the cached robot state from the connection's last telemetry.

.DESCRIPTION
    Returns the YarboRobot object from the most recent DeviceMSG without sending a command.
    Use -Refresh to force a new get_device_msg.

.PARAMETER Connection
    The connection to query. Defaults to the current default.

.PARAMETER Refresh
    Forces a get_device_msg command to update the cached state.

.EXAMPLE
    Get-YarboRobot

.EXAMPLE
    Get-YarboRobot -Refresh

.LINK
    Get-YarboStatus
#>
    [CmdletBinding()]
    [OutputType([YarboRobot])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter()]
        [switch]$Refresh
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection

        if ($Refresh -or $null -eq $conn.Robot) {
            return Get-YarboStatus -Connection $conn
        }

        return $conn.Robot
    }
}
