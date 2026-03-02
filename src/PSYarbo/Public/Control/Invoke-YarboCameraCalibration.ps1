function Invoke-YarboCameraCalibration {
    <#
.SYNOPSIS
    Runs camera calibration (camera_calibration).
.EXAMPLE
    Invoke-YarboCameraCalibration
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )
    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, 'Camera calibration')) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'camera_calibration' -Payload @{}
        }
    }
}
