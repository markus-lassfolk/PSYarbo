function Get-YarboProductCode {
    <#
.SYNOPSIS
    Retrieves the product code from the robot.

.DESCRIPTION
    Sends product_code_msg and returns the data feedback response containing
    the robot's product code/model identifier.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Get-YarboProductCode

.LINK
    Get-YarboRobot
    Get-YarboFirmware
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        Write-Verbose (Protect-YarboLogMessage "[Get-YarboProductCode] Routing via local MQTT → product_code_msg")
        $result = Send-MqttCommand -Connection $conn -Command 'product_code_msg' -Payload @{}

        if ($null -eq $result -or -not $result.Success) {
            if ($result) {
                $PSCmdlet.WriteError((New-YarboError -Message "product_code_msg failed: $($result.Message)" -ErrorId 'PSYarbo.CommandFailed.ProductCodeMsg' -Category 'InvalidResult'))
            }
            return
        }

        return $result.Data
    }
}
