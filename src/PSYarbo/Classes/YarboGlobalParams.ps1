<#
.SYNOPSIS
    Global robot parameters from read_global_params MQTT response.
    All fields from the data_feedback payload (MQTT reversing).
    RawData holds the full decoded payload for any extra keys the device sends.
#>
class YarboGlobalParams {
    [double]$MowSpeed
    [int]$CuttingHeight
    [int]$RainDelay
    [int]$ObstacleSensitivity
    [double]$Timestamp

    # Full MQTT payload so no keys are lost (e.g. future device fields)
    [PSCustomObject]$RawData

    [string] ToString() {
        return "MowSpeed=$($this.MowSpeed) CuttingHeight=$($this.CuttingHeight) RainDelay=$($this.RainDelay) ObstacleSensitivity=$($this.ObstacleSensitivity)"
    }
}
