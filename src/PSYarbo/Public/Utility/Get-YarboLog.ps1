function Get-YarboLog {
    <#
.SYNOPSIS
    Returns the internal command/response log for a Yarbo connection.

.DESCRIPTION
    Displays the history of MQTT commands sent and responses received.

.PARAMETER Connection
    The connection to query. Defaults to the current default.

.PARAMETER Last
    Number of recent entries to return. Default: 50.

.PARAMETER Filter
    Filter log entries: All, Commands, Telemetry, Errors. Default: All.

.EXAMPLE
    Get-YarboLog

.EXAMPLE
    Get-YarboLog -Last 10 -Filter Commands

.LINK
    Connect-Yarbo
    Send-YarboCommand
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection,

        [Parameter()]
        [int]$Last = 50,

        [Parameter()]
        [ValidateSet('All', 'Commands', 'Telemetry', 'Errors')]
        [string]$Filter = 'All'
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        $entries = $conn.CommandLog

        switch ($Filter) {
            'Commands' { $entries = $entries | Where-Object { $_.Direction -like 'Sent*' } }
            'Telemetry' { $entries = $entries | Where-Object { $_.Direction -eq 'Received' } }
            'Errors' { $entries = $entries | Where-Object { $_.State -and $_.State -ne 0 } }
        }

        $entries | Select-Object -Last $Last
    }
}
