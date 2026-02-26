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
    Hashtable of parameter key-value pairs to save. Obtain current values via
    Get-YarboGlobalParams and modify as needed.

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    $params = Get-YarboGlobalParams
    $params.mow_speed = 0.5
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
        [hashtable]$Parameters,

        [Parameter()]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection

        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Save global params: $($Parameters.Keys -join ', ')")) {
            Assert-YarboController -Connection $conn
            Write-Verbose (Protect-YarboLogMessage "[Set-YarboGlobalParams] Routing via local MQTT → cmd_save_para")
            $result = Send-MqttCommand -Connection $conn -Command 'cmd_save_para' -Payload $Parameters

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
