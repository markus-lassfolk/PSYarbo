#region Config file path
$script:YarboConfigDir = Join-Path $HOME '.psyarbo'
$script:YarboConfigFile = Join-Path $script:YarboConfigDir 'config.json'
#endregion

function Get-YarboConfig {
    <#
    .SYNOPSIS
        Returns the effective PSYarbo configuration, merging all sources.
    .DESCRIPTION
        Merges configuration from (highest to lowest priority):
          1. Explicit parameter values (Overrides)
          2. Environment variables (YARBO_BROKER, YARBO_SN, YARBO_PORT, YARBO_EMAIL)
          3. Config file (~/.psyarbo/config.json or -Path)
          4. Built-in defaults (Port=1883)
        Config file may use flat keys (Broker, Port, SN, Email) or schema defaults.broker, defaults.port, defaults.serialNumber.
    .PARAMETER Overrides
        Optional hashtable of caller-supplied values that take highest priority.
    .PARAMETER Path
        Optional path to config file. Defaults to ~/.psyarbo/config.json.
    #>
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [hashtable]$Overrides = @{},

        [Parameter()]
        [string]$Path
    )

    $configPath = if ($Path) { $Path } else { $script:YarboConfigFile }

    # Start with defaults
    $config = @{
        Broker = $null
        Port   = 1883
        SN     = $null
        Email  = $null
    }

    # Layer 1: config file
    if ($configPath -and (Test-Path $configPath)) {
        try {
            $fileConfig = Get-Content $configPath -Raw -ErrorAction Stop | ConvertFrom-Json
            # Flat keys
            foreach ($key in 'Broker', 'Port', 'SN', 'Email') {
                $val = $fileConfig.PSObject.Properties[$key]?.Value
                if ($null -ne $val -and "$val" -ne '') { $config[$key] = $val }
            }
            # Schema §10.4: defaults.broker, defaults.port, defaults.serialNumber (fill only if not already set)
            if ($fileConfig.PSObject.Properties['defaults']) {
                $d = $fileConfig.defaults
                if ($null -eq $config['Broker'] -and $d.PSObject.Properties['broker']?.Value) { $config['Broker'] = $d.broker }
                if ($null -eq $config['Port'] -and $null -ne $d.PSObject.Properties['port']?.Value) { $config['Port'] = [int]$d.port }
                if ($null -eq $config['SN'] -and $d.PSObject.Properties['serialNumber']?.Value) { $config['SN'] = $d.serialNumber }
            }
        } catch {
            Write-Warning "PSYarbo: Could not read config file '$configPath': $($_.Exception.Message)"
        }
    }

    # Layer 2: environment variables
    if ($env:YARBO_BROKER) { $config['Broker'] = $env:YARBO_BROKER }
    if ($env:YARBO_SN) { $config['SN'] = $env:YARBO_SN }
    if ($env:YARBO_PORT) { $config['Port'] = [int]$env:YARBO_PORT }
    if ($env:YARBO_EMAIL) { $config['Email'] = $env:YARBO_EMAIL }

    # Layer 3: explicit caller overrides (highest priority)
    foreach ($key in $Overrides.Keys) {
        $val = $Overrides[$key]
        if ($null -ne $val -and "$val" -ne '') { $config[$key] = $val }
    }

    return $config
}

function Save-YarboConfig {
    <#
    .SYNOPSIS
        Writes the given config object to ~/.psyarbo/config.json (or -Path).
    .PARAMETER Config
        Hashtable or PSCustomObject with keys Broker, Port, SN, Email (and optionally defaults, etc.).
    .PARAMETER Path
        Optional path. Defaults to ~/.psyarbo/config.json.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Private helper')]
    param(
        [Parameter(Mandatory)]
        [object]$Config,

        [Parameter()]
        [string]$Path
    )

    $configPath = if ($Path) { $Path } else { $script:YarboConfigFile }
    $configDir = Split-Path -Parent $configPath
    if (-not (Test-Path $configDir)) {
        $null = New-Item -ItemType Directory -Path $configDir -Force
    }
    $obj = if ($Config -is [hashtable]) {
        $Config
    } else {
        $h = @{}
        $Config.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }
        $h
    }
    $obj | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8
    Write-Verbose "PSYarbo: Saved config to $configPath"
}

function Merge-YarboConfig {
    <#
    .SYNOPSIS
        Merges config hierarchy: defaults &lt; file &lt; env &lt; explicit (highest wins).
    .PARAMETER Explicit
        Caller-supplied values (highest priority).
    .PARAMETER Env
        Values from environment (e.g. from Get-YarboConfig with no overrides, env-only).
    .PARAMETER File
        Values from config file.
    .PARAMETER Defaults
        Built-in defaults.
    #>
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [hashtable]$Explicit = @{},
        [Parameter()]
        [hashtable]$Env = @{},
        [Parameter()]
        [hashtable]$File = @{},
        [Parameter()]
        [hashtable]$Defaults = @{ Port = 1883 }
    )

    $result = @{}
    foreach ($h in @($Defaults, $File, $Env, $Explicit)) {
        if (-not $h) { continue }
        foreach ($key in $h.Keys) {
            $val = $h[$key]
            if ($null -ne $val -and "$val" -ne '') { $result[$key] = $val }
        }
    }
    return $result
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Private helper — state-change gate is in the calling public cmdlet')]
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
