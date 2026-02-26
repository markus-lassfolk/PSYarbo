class YarboException : System.Exception {
    [string]$ErrorId
    [string]$Command
    [string]$Remediation

    YarboException([string]$message) : base($message) { }

    YarboException([string]$message, [string]$errorId) : base($message) {
        $this.ErrorId = $errorId
    }

    YarboException([string]$message, [string]$errorId, [string]$remediation) : base($message) {
        $this.ErrorId = $errorId
        $this.Remediation = $remediation
    }
}

class YarboConnectionException : YarboException {
    [string]$Broker

    YarboConnectionException([string]$message, [string]$broker) : base($message, 'PSYarbo.Connection.Failed') {
        $this.Broker = $broker
        $this.Remediation = "Verify the MQTT broker at '$broker' is reachable. Check network connectivity and firewall rules."
    }
}

class YarboCommandException : YarboException {
    [int]$State
    [object]$Result

    YarboCommandException([object]$result) : base("Command '$($result.Topic)' failed: $($result.Message)", "PSYarbo.CommandFailed.$($result.Topic)") {
        $this.State = $result.State
        $this.Result = $result
        $this.Command = $result.Topic
        $this.Remediation = "Check robot state with Get-YarboStatus. The robot may need to be awake (Resume-Yarbo) or the controller re-acquired."
    }
}

class YarboTimeoutException : YarboException {
    [int]$TimeoutMs

    YarboTimeoutException([string]$command, [int]$timeoutMs) : base(
        "Command '$command' timed out after ${timeoutMs}ms.",
        "PSYarbo.Timeout.$command"
    ) {
        $this.Command = $command
        $this.TimeoutMs = $timeoutMs
        $this.Remediation = "Verify the robot is powered on and the MQTT broker is reachable. Try increasing the timeout or reconnecting."
    }
}

class YarboCloudAuthException : YarboException {
    [string]$ErrorCode

    YarboCloudAuthException([string]$message, [string]$code) : base($message, "PSYarbo.CloudAuth.$code") {
        $this.ErrorCode = $code
        $this.Remediation = "Check your credentials. If using a refresh token, it may have expired — re-authenticate with Connect-YarboCloud."
    }
}
