function Set-YarboChuteSteeringWork {
    <#
.SYNOPSIS
    Sets the chute steering state during work (snow blower head).

.DESCRIPTION
    Sends set_chute_steering_work. Aligns with python-yarbo set_chute_steering_work.

.PARAMETER State
    Chute steering state (robot-defined integer).

.PARAMETER Connection
    The connection to use. Defaults to the current default.

.EXAMPLE
    Set-YarboChuteSteeringWork -State 1

.LINK
    Set-YarboChute
    about_PSYarbo_Heads
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([YarboCommandResult])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [int]$State,

        [Parameter(ValueFromPipeline)]
        [YarboConnection]$Connection
    )

    process {
        $conn = Resolve-YarboConnection -Connection $Connection
        if ($PSCmdlet.ShouldProcess($conn.SerialNumber, "Set chute steering work state $State")) {
            Assert-YarboController -Connection $conn
            return Send-MqttCommand -Connection $conn -Command 'set_chute_steering_work' -Payload @{ state = $State }
        }
    }
}
