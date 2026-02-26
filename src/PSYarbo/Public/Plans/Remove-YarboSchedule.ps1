function Remove-YarboSchedule {
    <#
.SYNOPSIS
    Deletes a schedule from the robot.

.DESCRIPTION
    Sends del_schedule to remove the specified schedule by ID.

.PARAMETER ScheduleId
    The schedule ID to delete.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Remove-YarboSchedule -ScheduleId 3

.EXAMPLE
    Get-YarboSchedule | Where-Object { -not $_.Enabled } | Remove-YarboSchedule

.LINK
    Get-YarboSchedule
    Set-YarboSchedule
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [int]$ScheduleId,

        [Parameter()]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Delete schedule $ScheduleId")) {
            Write-Verbose (Protect-YarboLogMessage "[Remove-YarboSchedule] Routing via local MQTT → del_schedule")
            Send-MqttCommand -Connection $conn -Command 'del_schedule' -Payload @{ scheduleId = $ScheduleId } | Out-Null
        }
    }
}
