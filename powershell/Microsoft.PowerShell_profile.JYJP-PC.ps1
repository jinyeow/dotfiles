#Requires -Version 7

# ============================================================================
# PowerShell Profile — Optimised for fast startup via deferred loading
# ============================================================================
# Startup phases:
#   Phase 1 (blocking): Module scan, PSReadLine (History only), prompt definition
#   Phase 2 (first prompt): PSFzf, HistoryAndPlugin, zoxide — one-shot via prompt
#   Phase 3 (async): Az context via background runspace (in Set-Prompt.ps1)
# ============================================================================

# --- Module availability cache (single scan of PSModulePath) ---------------
$global:ProfileModules = @{}
$modulePaths = $env:PSModulePath -split [IO.Path]::PathSeparator
foreach ($name in @('PSFzf', 'posh-git', 'Az.Accounts', 'Az.Tools.Predictor', 'Microsoft.WinGet.CommandNotFound')) {
    $global:ProfileModules[$name] = $false
    foreach ($root in $modulePaths) {
        if (Test-Path (Join-Path $root $name)) {
            $global:ProfileModules[$name] = $true
            break
        }
    }
}

# --- PSReadLine (ships with pwsh 7, always available) ----------------------
# Phase 1: Use PredictionSource History (fast) — upgraded to HistoryAndPlugin in Phase 2
function OnViModeChange {
    if ($args[0] -eq 'Command') {
        Write-Host -NoNewline "`e[1 q"  # blinking block
    } else {
        Write-Host -NoNewline "`e[5 q"  # blinking line
    }
}

Set-PSReadLineOption -EditMode Vi `
    -PredictionSource History `
    -PredictionViewStyle ListView `
    -ShowToolTips `
    -HistoryNoDuplicates `
    -HistorySearchCursorMovesToEnd `
    -HistorySaveStyle SaveIncrementally `
    -ViModeIndicator Script `
    -ViModeChangeHandler $Function:OnViModeChange `
    -Colors @{
        Command          = 'Yellow'
        Parameter        = 'Green'
        String           = 'DarkCyan'
        InlinePrediction = 'DarkGray'
    }

Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory
Set-PSReadLineKeyHandler -Key Ctrl+Spacebar -Function MenuComplete
Set-PSReadLineKeyHandler -Key Tab -Function Complete
Set-PSReadLineKeyHandler -Chord Ctrl+Oem4 -Function ViCommandMode
Set-PSReadLineKeyHandler -Chord Shift+Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord Ctrl+b -Function BackwardChar
Set-PSReadLineKeyHandler -Chord Ctrl+f -Function ForwardChar
Set-PSReadLineKeyHandler -Chord Ctrl+p -Function PreviousHistory
Set-PSReadLineKeyHandler -Chord Ctrl+n -Function NextHistory
Set-PSReadLineKeyHandler -Chord Ctrl+a -Function BeginningOfLine
Set-PSReadLineKeyHandler -Chord Ctrl+e -Function EndOfLine
Set-PSReadLineKeyHandler -Chord Ctrl+w -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord Ctrl+u -Function BackwardDeleteLine

# --- Prompt -----------------------------------------------------------------
. "$(Split-Path -Path $PROFILE)/Profile/Set-Prompt.ps1"

# --- Az CLI tab completion --------------------------------------------------
if (Get-Command -Name az -ErrorAction Ignore) {
    Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        $completion_file = New-TemporaryFile
        $env:ARGCOMPLETE_USE_TEMPFILES = 1
        $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
        $env:COMP_LINE = $wordToComplete
        $env:COMP_POINT = $cursorPosition
        $env:_ARGCOMPLETE = 1
        $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
        $env:_ARGCOMPLETE_IFS = "`n"
        $env:_ARGCOMPLETE_SHELL = 'powershell'
        az 2>&1 | Out-Null
        Get-Content $completion_file | Sort-Object | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
    }
}

# --- Aliases ----------------------------------------------------------------
Set-Alias c clear -Force
Set-Alias -Name g -Value git
Set-Alias gcif Get-ChildItem -Force

# --- Functions --------------------------------------------------------------
function gst { git status }
function which ($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

$_chocoProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if ($_chocoProfile -and (Test-Path $_chocoProfile)) {
    function chocoRefresh {
        Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
        RefreshEnv
    }
}
Remove-Variable _chocoProfile

# --- Environment variables --------------------------------------------------
$env:XDG_CONFIG_HOME = "$HOME/.config"

# --- Deferred loading (Phase 2) --------------------------------------------
# Heavy modules loaded via PowerShell.OnIdle — the prompt appears immediately,
# and these load silently in the background while waiting for user input.
# Initialize-DeferredProfile guards with a boolean so it only runs once.
$global:ProfileDeferredDone = $false

function Initialize-DeferredProfile {
    if ($global:ProfileDeferredDone) { return }
    $global:ProfileDeferredDone = $true

    # WinGet CommandNotFound (~1.4s — .NET assembly loading)
    if ($global:ProfileModules['Microsoft.WinGet.CommandNotFound']) {
        Import-Module -Name Microsoft.WinGet.CommandNotFound
    }

    # Chocolatey (~790ms — .NET assembly loading)
    $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if ($ChocolateyProfile -and (Test-Path $ChocolateyProfile)) {
        Import-Module $ChocolateyProfile
    }

    # PSFzf (~1.1s)
    if ($global:ProfileModules['PSFzf']) {
        Import-Module PSFzf

        Set-Alias -Name frg -Value Invoke-PsFzfRipgrep -Scope Global

        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
        Set-PSReadLineKeyHandler -Chord 'alt+f' -ScriptBlock { Invoke-PsFzfRipgrep -SearchString '.' }

        Set-PsFzfOption `
            -AltCCommand ([ScriptBlock] { param($Location) Write-Host $Location }) `
            -EnableAliasFuzzyEdit `
            -EnableAliasFuzzyGitStatus `
            -EnableAliasFuzzyHistory `
            -EnableAliasFuzzyKillProcess `
            -EnableAliasFuzzySetLocation `
            -PSReadlineChordProvider 'Ctrl+t' `
            -PSReadlineChordReverseHistory 'Ctrl+r'
    }

    # Upgrade prediction source to include Az.Tools.Predictor plugin (~650ms)
    if ($global:ProfileModules['Az.Tools.Predictor']) {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    }

    # Zoxide (~340ms)
    if (Get-Command -Name zoxide -ErrorAction Ignore) {
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    }
}

# Fire deferred loading on first idle.
# OnIdle fires repeatedly (~2x/sec), but Initialize-DeferredProfile guards
# with $global:ProfileDeferredDone and returns immediately after the first run.
# Idempotent for . $PROFILE reloads.
Get-EventSubscriber -ErrorAction SilentlyContinue |
    Where-Object { $_.SourceIdentifier -eq 'PowerShell.OnIdle' -and $_.Action.Command -match 'DeferredProfile' } |
    Unregister-Event
Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -Action {
    Initialize-DeferredProfile
} | Out-Null
