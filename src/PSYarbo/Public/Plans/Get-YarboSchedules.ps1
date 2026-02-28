function Get-YarboSchedules {
    <#
.SYNOPSIS
    Retrieves all schedules from the robot.

.DESCRIPTION
    Sends read_schedules and returns the raw data feedback response containing
    all stored schedule configurations. For a typed schedule object, use
    Get-YarboSchedule.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboSchedules

.EXAMPLE
    Get-YarboSchedules | ConvertTo-Json -Depth 5

.LINK
    Get-YarboSchedule
    Set-YarboSchedule
    Remove-YarboSchedule
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = '"Schedules" returns the full schedule collection; the plural is intentional')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboSchedules] Routing via local MQTT → read_schedules")
        $result = Send-MqttCommand -Connection $conn -Command 'read_schedules' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "read_schedules failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.ReadSchedules' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
