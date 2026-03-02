class YarboEndpoint {
    [string]$IPAddress
    [int]$Port
    [string]$Path
    [string]$MacAddress
    [bool]$Recommended
    [string]$Hostname
    [string]$SerialNumber
    [string]$Status

    [string] ToString() {
        $rec = if ($this.Recommended) { ' (recommended)' } else { '' }
        return "$($this.IPAddress):$($this.Port) $($this.Path)$rec"
    }
}
