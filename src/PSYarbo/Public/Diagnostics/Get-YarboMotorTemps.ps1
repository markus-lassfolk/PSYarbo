function Get-YarboMotorTemps {
    <#
.SYNOPSIS
    Retrieves motor temperature readings from the robot.

.DESCRIPTION
    Sends motor_temp_samp and returns the data feedback response containing
    temperature samples for the robot's motors.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboMotorTemps

.EXAMPLE
    Get-YarboMotorTemps | ConvertTo-Json

.LINK
    Get-YarboBatteryCellTemps
    Get-YarboBodyCurrent
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = '"MotorTemps" describes multiple motor temperature readings; the plural is intentional')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboMotorTemps] Routing via local MQTT → motor_temp_samp")
        $result = Send-MqttCommand -Connection $conn -Command 'motor_temp_samp' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "motor_temp_samp failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.MotorTempSamp' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
