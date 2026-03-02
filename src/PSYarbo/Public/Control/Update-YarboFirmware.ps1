function Update-YarboFirmware {
    <#
.SYNOPSIS
    Triggers or schedules a firmware update.

.DESCRIPTION
    Sends firmware_update_now, firmware_update_tonight, or firmware_update_later.
    Aligns with python-yarbo. -When Now is destructive and requires -Confirm.

.PARAMETER When
    Now = immediate (requires -Confirm), Tonight = schedule for tonight, Later = defer.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Update-YarboFirmware -When Tonight

.EXAMPLE
    Update-YarboFirmware -When Now -Confirm
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('Now', 'Tonight', 'Later')]
        [string]$When,

        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )
    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        $cmd = switch ($When) {
            'Now'     { 'firmware_update_now' }
            'Tonight' { 'firmware_update_tonight' }
            'Later'   { 'firmware_update_later' }
        }
        $action = "Firmware update $When"
        if ($When -eq 'Now') {
            $action = 'Firmware update NOW (destructive)'
        }
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, $action)) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command $cmd -Payload @{}
        }
    }
}
