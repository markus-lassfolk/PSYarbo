function Set-YarboGlobalParams {
    <#
.SYNOPSIS
    Saves global robot parameters.

.DESCRIPTION
    Sends cmd_save_para with the provided parameter hashtable to persist global
    robot configuration. Use Get-YarboGlobalParams first to retrieve the current
    values, modify the desired fields, then pass the hashtable to this cmdlet.

    This is a HIGH impact operation — incorrect parameters may affect robot
    behaviour. Use -WhatIf or -Confirm to preview changes before applying.

.PARAMETER Parameters
    Hashtable of parameter key-value pairs to save, or a YarboGlobalParams object
    from Get-YarboGlobalParams. When passing a YarboGlobalParams object, the RawData
    property is used to send all parameters back to the device.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    $params = Get-YarboGlobalParams
    $params.RawData.mow_speed = 0.5
    Set-YarboGlobalParams -Parameters $params

.EXAMPLE
    Set-YarboGlobalParams -Parameters @{ mow_speed = 0.3 } -Confirm

.LINK
    Get-YarboGlobalParams
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns', '',
        Justification = '"Params" is an established abbreviation for Parameters; renaming would break the documented API')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [object]$Parameters,

        [Parameter()]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection

        $payload = if ($Parameters -is [YarboGlobalParams]) {
            if ($Parameters.RawData) {
                $ht = @{}
                foreach ($prop in $Parameters.RawData.PSObject.Properties) {
                    $ht[$prop.Name] = $prop.Value
                }
                
                # Sync typed properties back to payload to prevent silent data loss
                if ($null -ne $Parameters.MowSpeed) { $ht['mow_speed'] = $Parameters.MowSpeed }
                if ($null -ne $Parameters.CuttingHeight) { $ht['cutting_height'] = $Parameters.CuttingHeight }
                if ($null -ne $Parameters.RainDelay) { $ht['rain_delay'] = $Parameters.RainDelay }
                if ($null -ne $Parameters.ObstacleSensitivity) { $ht['obstacle_sensitivity'] = $Parameters.ObstacleSensitivity }
                
                $ht
            } else {
                throw "YarboGlobalParams object has no RawData. Use Get-YarboGlobalParams to retrieve current parameters first."
            }
        } elseif ($Parameters -is [hashtable]) {
            $Parameters
        } else {
            throw "Parameters must be a hashtable or YarboGlobalParams object."
        }

        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Save global params: $($payload.Keys -join ', ')")) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboGlobalParams] Routing via local MQTT → cmd_save_para")
            $result = Send-MqttCommand -Connection $conn -Command 'cmd_save_para' -Payload $payload

            if ($result -and -not $result.Success) {
                $PSCmdlet.WriteError((New-YarboError `
                            -Message "cmd_save_para failed: $($result.Message)" `
                            -ErrorId 'PSYarbo.CommandFailed.SaveGlobalParams' `
                            -Category 'InvalidResult' `
                            -TargetObject $result))
            }

            return $result
        }
    }
}
