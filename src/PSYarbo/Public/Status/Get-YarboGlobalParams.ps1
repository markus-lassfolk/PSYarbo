function Get-YarboGlobalParams {
    <#
.SYNOPSIS
    Retrieves global robot parameters.

.DESCRIPTION
    Sends read_global_params and returns the parsed parameters object from the
    data_feedback response. Global parameters include operational settings
    such as mowing speed, cutting height, and other robot-wide configuration.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboGlobalParams

.EXAMPLE
    $params = Get-YarboGlobalParams
    $params | Format-List

.LINK
    Set-YarboGlobalParams
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = '"Params" is an established abbreviation for Parameters; renaming would break the documented API')]
    [CmdletBinding()]
    [OutputType([YarboGlobalParams])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboGlobalParams] Routing via local MQTT → read_global_params")

        $result = Send-MqttCommand -Connection $conn -Command 'read_global_params' -Payload @{} -TimeoutMs 5000

        if ($result.TimedOut) {
            $PSCmdlet.WriteError((New-YarboError `
                        -Message "Timed out waiting for global params response." `
                        -ErrorId 'PSYarbo.Timeout.ReadGlobalParams' `
                        -Category 'OperationTimeout' `
                        -TargetObject $conn `
                        -Exception ([YarboTimeoutException]::new('read_global_params', 5000))))
            return
        }

        if (-not $result.Success) {
            $PSCmdlet.WriteError((New-YarboError `
                        -Message "read_global_params failed: $($result.Message)" `
                        -ErrorId 'PSYarbo.CommandFailed.ReadGlobalParams' `
                        -Category 'InvalidResult' `
                        -TargetObject $result))
            return
        }

        $p = [YarboGlobalParams]::new()
        $d = $result.Data
        $p.RawData = $d
        if ($d.PSObject.Properties['mow_speed']) { $p.MowSpeed = [double]$d.mow_speed }
        if ($d.PSObject.Properties['cutting_height']) { $p.CuttingHeight = [int]$d.cutting_height }
        if ($d.PSObject.Properties['rain_delay']) { $p.RainDelay = [int]$d.rain_delay }
        if ($d.PSObject.Properties['obstacle_sensitivity']) { $p.ObstacleSensitivity = [int]$d.obstacle_sensitivity }
        if ($d.PSObject.Properties['timestamp']) { $p.Timestamp = [double]$d.timestamp }
        return $p
    }
}
