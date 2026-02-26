class YarboPlan {
    [int]$Id
    [string]$Name
    [int[]]$AreaIds
    [bool]$EnableSelfOrder

    [string] ToString() { return "$($this.Id): $($this.Name) (Areas: $($this.AreaIds -join ','))" }
}

class YarboPlanFeedback {
    [string]$PlanId
    [double]$AreaCovered
    [int]$Duration
    [int]$State
    [datetime]$Timestamp

    [string] ToString() {
        return "Plan[$($this.PlanId)] Area:$($this.AreaCovered) Duration:$($this.Duration)s State:$($this.State)"
    }
}
