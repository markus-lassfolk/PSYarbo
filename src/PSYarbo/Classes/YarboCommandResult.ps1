class YarboCommandResult {
    [string]$Topic
    [int]$State
    [string]$Message
    [PSCustomObject]$Data
    [datetime]$Timestamp
    [bool]$Success
    [bool]$TimedOut

    YarboCommandResult() { }

    YarboCommandResult([PSCustomObject]$feedback) {
        $this.Topic = $feedback.topic
        $this.State = $feedback.state
        $this.Message = $feedback.msg
        $this.Data = $feedback.data
        $this.Timestamp = [datetime]::UtcNow
        $this.Success = ($feedback.state -eq 0)
        $this.TimedOut = $false
    }

    # Factory: creates a timed-out result marker (no throw required)
    static [YarboCommandResult] Timeout([string]$command, [int]$timeoutMs) {
        $r = [YarboCommandResult]::new()
        $r.Topic     = $command
        $r.State     = -1
        $r.Message   = "Timed out after ${timeoutMs}ms waiting for '$command' response"
        $r.Timestamp = [datetime]::UtcNow
        $r.Success   = $false
        $r.TimedOut  = $true
        return $r
    }

    [string] ToString() {
        if ($this.TimedOut) { return "⏱ $($this.Topic): timed out" }
        $icon = if ($this.Success) { '✓' } else { '✗' }
        return "$icon $($this.Topic): $($this.Message)"
    }
}
