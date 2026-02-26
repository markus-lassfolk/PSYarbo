function Get-YarboBattery {
    <#
.SYNOPSIS
    Returns the robot's battery capacity (0-100%).

.DESCRIPTION
    Returns the current battery level from cached telemetry or by requesting fresh data.

.PARAMETER Connection
    The connection to query. Defaults to the current default.

.EXAMPLE
    Get-YarboBattery

.LINK
    Get-YarboStatus
#>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        $robot = Get-YarboRobot -Connection $conn -Refresh
        return $robot.BatteryCapacity
    }
}
