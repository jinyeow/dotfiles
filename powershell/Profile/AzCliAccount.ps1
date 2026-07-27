# ============================================================================
# AzCliAccount.ps1 — switch the Azure CLI between NAMED profiles
# ============================================================================
# Each profile is a self-contained AZURE_CONFIG_DIR under ~/.azure-profiles/<name>,
# so a dir never caches more than one identity. Defines functions only; NO side
# effects at dot-source. The profile calls Restore-AzActiveProfile explicitly in
# Phase 1 (mirroring how Set-Prompt.ps1 defines Initialize-AzTimer but the profile
# calls it).
# ============================================================================

function Test-AzProfileName {
    <#
    .SYNOPSIS
    True when the string is a usable az profile name. Also the path-injection guard:
    a name becomes a directory under ~/.azure-profiles, so separators and traversal
    must never pass. Pure string test — no filesystem access, safe to call from the
    Phase 1 restore path.
    #>
    [OutputType([bool])]
    param([string]$Name)

    return $Name -match '^[A-Za-z0-9][A-Za-z0-9_-]*$'
}

function Get-AzProfileIdentity {
    <#
    .SYNOPSIS
    The identity cached in a profile's azureProfile.json, for the picker's preview column.
    .DESCRIPTION
    A plain file read — never an `az` process — so the preview costs nothing per keystroke
    and works while logged out. A missing, unreadable, or unparsable file yields the login
    hint rather than an error: the picker must list a profile that has never been used.
    #>
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Name)

    [string]$notLoggedIn = 'not logged in — run: az login'
    [string]$dir = if ($Name -eq 'default') {
        Join-Path $HOME '.azure'
    } else {
        Join-Path $HOME '.azure-profiles' $Name
    }
    [string]$file = Join-Path $dir 'azureProfile.json'
    if (-not (Test-Path -LiteralPath $file)) { return $notLoggedIn }

    try {
        $parsed = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
    } catch {
        return $notLoggedIn
    }

    [object[]]$subscriptions = @($parsed.subscriptions)
    if (-not $subscriptions) { return $notLoggedIn }

    # Users first — that is the identity the one-identity-per-profile rule is about. A
    # service-principal / managed-identity login writes no user.name, so fall back to the
    # subscription names rather than mislabelling a real login as logged out.
    [string[]]$users = @($subscriptions.user.name | Where-Object { $_ } | Select-Object -Unique)
    [string]$identity = if ($users) { $users -join ', ' } else { '' }

    $active = @($subscriptions | Where-Object { $_.isDefault })[0]
    [string]$subscription = if ($active) { $active.name } else { $subscriptions[0].name }
    if ($subscription) {
        $identity = if ($identity) { "$identity — $subscription" } else { $subscription }
    }

    if (-not $identity) { return $notLoggedIn }
    return $identity
}

function Show-AzAccountStatus {
    <#
    .SYNOPSIS
    Best-effort: append the active az account (or a login hint) after a switch
    announce. Must never throw or block — az may be slow, absent, or logged out, and
    the deterministic announce has already printed. Never runs `az login` itself.
    #>
    try {
        $account = az account show --query 'user.name' --output tsv 2>$null
        if ($LASTEXITCODE -eq 0 -and $account) {
            Write-Host "  active: $account" -ForegroundColor DarkGray
        } else {
            Write-Host '  not logged in — run: az login' -ForegroundColor DarkGray
        }
    } catch {
        Write-Host '  not logged in — run: az login' -ForegroundColor DarkGray
    }
}

function Select-AzProfileName {
    <#
    .SYNOPSIS
    Pick a profile interactively with fzf, showing each candidate's cached identity.
    Returns the picked name, or an empty string when the pick is cancelled.
    .DESCRIPTION
    The ONLY discovery-by-enumeration path — Restore-AzActiveProfile must never call it.
    Identities are precomputed into a tab-delimited second field so the preview is a bare
    echo: no pwsh or az process is spawned per keystroke.
    #>
    [OutputType([string])]
    param()

    if (-not (Get-Command fzf -ErrorAction Ignore)) {
        throw 'fzf was not found on PATH, so the az profile picker cannot run. Install fzf, or name the profile explicitly: Switch-AzProfile -Name <profile>.'
    }

    [string]$container = Join-Path $HOME '.azure-profiles'
    [string[]]$names = @('default')
    if (Test-Path -LiteralPath $container) {
        $names += @(Get-ChildItem -LiteralPath $container -Directory | Select-Object -ExpandProperty Name)
    }

    # Bare fzf (native pipeline), NOT PSFzf's Invoke-Fzf: its redirected-stdout
    # System.Diagnostics.Process launcher desyncs under psmux's ConPTY.
    [string]$picked = $names |
        ForEach-Object { "$_`t$(Get-AzProfileIdentity -Name $_)" } |
        fzf --prompt 'az profile> ' --delimiter "`t" --with-nth 1 --preview 'echo {2..}'

    if ([string]::IsNullOrWhiteSpace($picked)) { return '' }
    return ($picked -split "`t")[0]
}

function Switch-AzProfile {
    <#
    .SYNOPSIS
    Switch the Azure CLI to a named profile by pointing AZURE_CONFIG_DIR at
    ~/.azure-profiles/<name>, so each profile's token cache holds exactly one identity.
    .DESCRIPTION
    Persists the choice to the ~/.azure-active-profile state file so a new shell
    restores it, clears the session-cached ADO bearer token (so prr re-authenticates
    against this account), then announces the switch and — best effort — the active
    account. Aliased as azs.
    #>
    param([string]$Name)

    # Only an OMITTED -Name opens the picker: `azs ''` is a bug in the caller, so it must
    # fall through to validation and throw rather than turning interactive.
    if (-not $PSBoundParameters.ContainsKey('Name')) {
        $Name = Select-AzProfileName
        # Cancelled pick — leave every bit of state alone.
        if (-not $Name) { return }
    }

    if (-not (Test-AzProfileName -Name $Name)) {
        throw "Invalid az profile name '$Name'. Names must match '^[A-Za-z0-9][A-Za-z0-9_-]*$' — letters, digits, underscore and hyphen only, starting with a letter or digit."
    }

    [string]$announce = ''
    if ($Name -eq 'default') {
        # Reserved: `default` IS az's own ~/.azure, so unset rather than point at a
        # ~/.azure-profiles/default dir — and create nothing.
        Remove-Item Env:AZURE_CONFIG_DIR -ErrorAction Ignore
        $announce = '→ az profile → default (az''s own ~/.azure)'
    } else {
        [string]$dir = Join-Path $HOME '.azure-profiles' $Name
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "  created $dir — run: az login" -ForegroundColor DarkGray
        }
        $env:AZURE_CONFIG_DIR = $dir
        $announce = "→ az profile → $Name ($dir)"
    }

    Set-Content -LiteralPath (Join-Path $HOME '.azure-active-profile') -Value $Name
    # Force prr/Invoke-AdoPrReview to re-fetch a token for the now-active account
    # instead of listing the previous account's PRs from the stale cached token.
    $global:__AdoAccessToken = $null
    Write-Host $announce -ForegroundColor Magenta
    Show-AzAccountStatus
}

function Restore-AzActiveProfile {
    <#
    .SYNOPSIS
    Apply the last-used az profile by reading the ~/.azure-active-profile state file
    and setting AZURE_CONFIG_DIR accordingly. Silent by design — the profile calls it
    in Phase 1 and startup must stay quiet. Not aliased; called once at profile load.
    #>
    # Unconditional and first, so it holds on every code path: AZURE_EXTENSION_DIR
    # decouples the extension store from AZURE_CONFIG_DIR. Without it a non-default
    # profile sees ZERO extensions and az devops / az graph break. One shared store
    # for every profile, never per-profile. One assignment, no read.
    $env:AZURE_EXTENSION_DIR = Join-Path $HOME '.azure' 'cliextensions'

    # Phase 1 cost budget: exactly ONE state-file read, no enumeration, no JSON.
    [string]$stateFile = Join-Path $HOME '.azure-active-profile'
    [string]$state = ''
    if (Test-Path -LiteralPath $stateFile) {
        $state = [string](Get-Content -LiteralPath $stateFile -ErrorAction Ignore | Select-Object -First 1)
    }
    $state = $state.Trim()
    if ($state -ne 'default' -and (Test-AzProfileName -Name $state)) {
        # No existence check — a missing dir just means az sees an empty config until
        # the user switches or logs in, and a second FS touch buys nothing.
        $env:AZURE_CONFIG_DIR = Join-Path $HOME '.azure-profiles' $state
    } else {
        # default, missing, empty, or invalid — ACTIVELY unset, never merely skip, so an
        # inherited/parent AZURE_CONFIG_DIR can't survive.
        Remove-Item Env:AZURE_CONFIG_DIR -ErrorAction Ignore
    }

    # Restore changes the active account exactly as Switch-AzProfile does, so it owes the
    # same clear. A fresh shell has nothing cached, but `. $PROFILE` in a session that has
    # already run prr does — and if another shell rewrote the state file meanwhile, prr
    # would otherwise list the PREVIOUS account's PRs from the stale session token.
    $global:__AdoAccessToken = $null
}

Set-Alias -Name azs -Value Switch-AzProfile
