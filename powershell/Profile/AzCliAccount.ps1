# ============================================================================
# AzCliAccount.ps1 — switch the Azure CLI between PERSONAL and WORK accounts
# ============================================================================
# Defines functions only; NO side effects at dot-source. The profile calls
# Restore-AzActiveProfile explicitly in Phase 1 (mirroring how Set-Prompt.ps1
# defines Initialize-AzTimer but the profile calls it).
# ============================================================================

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

function Switch-AzPersonal {
    <#
    .SYNOPSIS
    Switch the Azure CLI to the PERSONAL account by pointing AZURE_CONFIG_DIR at an
    isolated per-account config dir (~/.azure-personal), so its token cache never
    mixes with the work login under the default ~/.azure.
    .DESCRIPTION
    Persists the choice to the ~/.azure-active-profile state file so a new shell
    restores it, clears the session-cached ADO bearer token (so prr re-authenticates
    against this account), then announces the switch and — best effort — the active
    account. Aliased as azp.
    #>
    $dir = Join-Path $HOME '.azure-personal'
    $env:AZURE_CONFIG_DIR = $dir
    Set-Content -LiteralPath (Join-Path $HOME '.azure-active-profile') -Value 'personal'
    # Force prr/Invoke-AdoPrReview to re-fetch a token for the now-active account
    # instead of listing the previous account's PRs from the stale cached token.
    $global:__AdoAccessToken = $null
    Write-Host "→ az account → personal ($dir)" -ForegroundColor Magenta
    Show-AzAccountStatus
}

function Switch-AzWork {
    <#
    .SYNOPSIS
    Switch the Azure CLI back to the WORK account by unsetting AZURE_CONFIG_DIR, so az
    falls back to the default ~/.azure that already holds the work login.
    .DESCRIPTION
    Persists the choice to the ~/.azure-active-profile state file so a new shell
    restores it, clears the session-cached ADO bearer token (so prr re-authenticates
    against this account), then announces the switch and — best effort — the active
    account. Aliased as azw.
    #>
    Remove-Item Env:AZURE_CONFIG_DIR -ErrorAction Ignore
    Set-Content -LiteralPath (Join-Path $HOME '.azure-active-profile') -Value 'work'
    # Force prr/Invoke-AdoPrReview to re-fetch a token for the now-active account
    # instead of listing the previous account's PRs from the stale cached token.
    $global:__AdoAccessToken = $null
    Write-Host '→ az account → work (default ~/.azure)' -ForegroundColor Cyan
    Show-AzAccountStatus
}

function Restore-AzActiveProfile {
    <#
    .SYNOPSIS
    Apply the last-used az account by reading the ~/.azure-active-profile state file
    and setting AZURE_CONFIG_DIR accordingly. Silent by design — the profile calls it
    in Phase 1 and startup must stay quiet. Not aliased; called once at profile load.
    #>
    $stateFile = Join-Path $HOME '.azure-active-profile'
    $state = if (Test-Path -LiteralPath $stateFile) {
        (Get-Content -LiteralPath $stateFile -ErrorAction Ignore | Select-Object -First 1)
    }
    if ($state) { $state = $state.Trim() }
    if ($state -eq 'personal') {
        $env:AZURE_CONFIG_DIR = Join-Path $HOME '.azure-personal'
    } else {
        # work, missing, empty, or unrecognized — ACTIVELY unset, never merely skip, so an
        # inherited/parent AZURE_CONFIG_DIR can't survive against a non-personal state.
        Remove-Item Env:AZURE_CONFIG_DIR -ErrorAction Ignore
    }
}

Set-Alias -Name azp -Value Switch-AzPersonal
Set-Alias -Name azw -Value Switch-AzWork
