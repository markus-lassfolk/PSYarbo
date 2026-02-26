function Resolve-YarboConnection {
    <#
    .SYNOPSIS
        Resolves the active YarboConnection from parameter, serial number, or default.
    #>
    [OutputType([YarboConnection])]
    param(
        [Parameter()]
        [YarboConnection]$Connection,

        [Parameter()]
        [string]$SerialNumber
    )

    if ($Connection) { return $Connection }
    if ($SerialNumber -and $script:YarboConnections.ContainsKey($SerialNumber)) {
        return $script:YarboConnections[$SerialNumber]
    }
    if ($script:DefaultConnection) { return $script:DefaultConnection }

    throw [YarboConnectionException]::new(
        "No active Yarbo connection. Use Connect-Yarbo first.",
        'none'
    )
}
