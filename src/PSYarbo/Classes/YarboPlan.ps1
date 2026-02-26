class YarboPlan {
    [int]$Id
    [string]$Name
    [int[]]$AreaIds
    [bool]$EnableSelfOrder

    [string] ToString() { return "$($this.Id): $($this.Name) (Areas: $($this.AreaIds -join ','))" }
}
