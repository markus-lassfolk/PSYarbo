class YarboCommandResult {
    [string]$Topic
    [int]$State
    [string]$Message
    [PSCustomObject]$Data
    [datetime]$Timestamp
    [bool]$Success

    YarboCommandResult() { }

    YarboCommandResult([PSCustomObject]$feedback) {
        $this.Topic = $feedback.topic
        $this.State = $feedback.state
        $this.Message = $feedback.msg
        $this.Data = $feedback.data
        $this.Timestamp = [datetime]::UtcNow
        $this.Success = ($feedback.state -eq 0)
    }

    [string] ToString() {
        $icon = if ($this.Success) { '✓' } else { '✗' }
        return "$icon $($this.Topic): $($this.Message)"
    }
}
