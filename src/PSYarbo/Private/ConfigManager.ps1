#region Config file path
$script:YarboConfigDir  = Join-Path $HOME '.psyarbo'
$script:YarboConfigFile = Join-Path $script:YarboConfigDir 'config.json'
#endregion

function Get-YarboConfig {
    <#
    .SYNOPSIS
        Returns the effective PSYarbo configuration, merging all sources.
    .DESCRIPTION
        Merges configuration from (highest to lowest priority):
          1. Explicit parameter values already resolved by the caller
          2. Environment variables (YARBO_BROKER, YARBO_SN, YARBO_PORT, YARBO_EMAIL)
          3. Config file (~/.psyarbo/config.json)
          4. Built-in defaults (Port=1883)
    .PARAMETER Overrides
        Optional hashtable of caller-supplied values that take highest priority.
        Null/empty values in Overrides are treated as unset.
    #>
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [hashtable]$Overrides = @{}
    )

    # Start with defaults
    $config = @{
        Broker = $null
        Port   = 1883
        SN     = $null
        Email  = $null
    }

    # Layer 1: config file
    if (Test-Path $script:YarboConfigFile) {
        try {
            $fileConfig = Get-Content $script:YarboConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json
            foreach ($key in 'Broker', 'Port', 'SN', 'Email') {
                $val = $fileConfig.PSObject.Properties[$key]?.Value
                if ($null -ne $val -and "$val" -ne '') { $config[$key] = $val }
            }
        } catch {
            Write-Warning "PSYarbo: Could not read config file '$script:YarboConfigFile': $($_.Exception.Message)"
        }
    }

    # Layer 2: environment variables
    if ($env:YARBO_BROKER) { $config['Broker'] = $env:YARBO_BROKER }
    if ($env:YARBO_SN)     { $config['SN']     = $env:YARBO_SN }
    if ($env:YARBO_PORT)   { $config['Port']   = [int]$env:YARBO_PORT }
    if ($env:YARBO_EMAIL)  { $config['Email']  = $env:YARBO_EMAIL }

    # Layer 3: explicit caller overrides (highest priority, skip null/empty)
    foreach ($key in $Overrides.Keys) {
        $val = $Overrides[$key]
        if ($null -ne $val -and "$val" -ne '') { $config[$key] = $val }
    }

    return $config
}

function Set-YarboConfig {
    <#
    .SYNOPSIS
        Saves a key-value pair to the PSYarbo config file (~/.psyarbo/config.json).
    .PARAMETER Key
        Configuration key: Broker, Port, SN, or Email.
    .PARAMETER Value
        Value to save.
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Broker', 'Port', 'SN', 'Email')]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Value
    )

    if (-not (Test-Path $script:YarboConfigDir)) {
        $null = New-Item -ItemType Directory -Path $script:YarboConfigDir -Force
    }

    $existing = @{}
    if (Test-Path $script:YarboConfigFile) {
        try {
            $fileConfig = Get-Content $script:YarboConfigFile -Raw | ConvertFrom-Json
            $fileConfig.PSObject.Properties | ForEach-Object { $existing[$_.Name] = $_.Value }
        } catch {
            Write-Warning "PSYarbo: Could not read existing config; overwriting. Error: $($_.Exception.Message)"
        }
    }

    $existing[$Key] = $Value
    $existing | ConvertTo-Json -Depth 5 | Set-Content -Path $script:YarboConfigFile -Encoding UTF8

    Write-Verbose "PSYarbo: Set config '$Key' in $script:YarboConfigFile"
}

function Test-YarboConfig {
    <#
    .SYNOPSIS
        Tests whether a minimal PSYarbo configuration is available.
    .DESCRIPTION
        Returns $true if at least Broker and SN are resolvable from any source
        (env vars, config file, or provided overrides).
    .PARAMETER Overrides
        Optional caller-supplied overrides to include in the test.
    #>
    [OutputType([bool])]
    param(
        [Parameter()]
        [hashtable]$Overrides = @{}
    )

    $cfg = Get-YarboConfig -Overrides $Overrides
    return ($null -ne $cfg['Broker'] -and $null -ne $cfg['SN'])
}
