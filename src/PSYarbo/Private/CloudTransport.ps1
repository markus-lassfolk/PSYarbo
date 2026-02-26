function Invoke-YarboCloudApi {
    <#
    .SYNOPSIS
        Makes an authenticated REST call to the Yarbo cloud API.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [YarboCloudSession]$Session,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [hashtable]$Body,

        [Parameter()]
        [string]$CmdletName = 'Invoke-YarboCloudApi'
    )

    Write-Verbose (Protect-YarboLogMessage "[$CmdletName] Routing via cloud REST → $Method $Path")

    $result = $Session.Invoke($Method, $Path, $Body)

    if ($result.success -eq $false) {
        $codeStr = if ($null -ne $result.code) { $result.code.ToString() } else { 'UNKNOWN' }
        throw [YarboCloudAuthException]::new(
            "Cloud API call failed: $($result.message). Path: $Path",
            $codeStr
        )
    }

    return $result.data
}
