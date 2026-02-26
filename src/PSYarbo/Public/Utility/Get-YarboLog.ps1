function Get-YarboLog {
    <#
.SYNOPSIS
    Returns the internal command/response log for a Yarbo connection.

.DESCRIPTION
    Displays the history of MQTT commands sent and responses received (CommandLog),
    or the recent push-telemetry event log (TelemetryLog).

    Filter values:
      All       — all CommandLog entries (sent commands + data_feedback responses)
      Commands  — only sent commands (Direction like 'Sent*')
      Received  — only data_feedback responses received for commands (Direction = 'Received')
      Telemetry — push-telemetry events from the MQTT broker (DeviceMSG, HeartBeat,
                  PlanFeedback, RechargeFeedback). These are NOT command responses —
                  they are unsolicited messages pushed by the robot at 1-2 Hz.
      Errors    — CommandLog entries with non-zero state

.PARAMETER Connection
    The connection to query. Defaults to the current default.

.PARAMETER Last
    Number of recent entries to return. Default: 50.

.PARAMETER Filter
    Filter log entries: All, Commands (sent), Received (data_feedback responses),
    Telemetry (push events from robot), Errors (non-zero state). Default: All.

.EXAMPLE
    Get-YarboLog

.EXAMPLE
    Get-YarboLog -Last 10 -Filter Commands

.EXAMPLE
    Get-YarboLog -Filter Telemetry -Last 20

.EXAMPLE
    Get-YarboLog -Filter Errors

.LINK
    Connect-Yarbo
    Send-YarboCommand
    Watch-YarboTelemetry
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Last = 50,

        [Parameter()]
        [ValidateSet('All', 'Commands', 'Received', 'Telemetry', 'Errors')]
        [string]$Filter = 'All'
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection

        if ($Filter -eq 'Telemetry') {
            # Return push-telemetry events (DeviceMSG, HeartBeat, PlanFeedback, etc.)
            $conn.TelemetryLog.ToArray() | Select-Object -Last $Last
            return
        }

        $entries = $conn.CommandLog.ToArray()

        switch ($Filter) {
            'Commands' { $entries = $entries | Where-Object { $_.Direction -like 'Sent*' } }
            'Received' { $entries = $entries | Where-Object { $_.Direction -eq 'Received' } }
            'Errors' { $entries = $entries | Where-Object { $_.State -and $_.State -ne 0 } }
        }

        $entries | Select-Object -Last $Last
    }
}
