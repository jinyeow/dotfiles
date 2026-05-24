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
Set-PSReadLineKeyHandler -Chord 'Ctrl+?' -ScriptBlock { Show-Hotkeys | Out-Null; [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() }

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
if ($PSVersionTable.PSVersion.Major -eq 5) {
    Remove-Item alias:wget -ErrorAction SilentlyContinue
    Remove-Item alias:curl -ErrorAction SilentlyContinue
}
Set-Alias c clear -Force
Set-Alias -Name g -Value git
Set-Alias gcif Get-ChildItem -Force

# --- Functions --------------------------------------------------------------
function gst { git status }
function which ($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}
function Start-AdminSession { Start-Process wt -Verb RunAs }
Set-Alias -Name su -Value Start-AdminSession

$_chocoProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if ($_chocoProfile -and (Test-Path $_chocoProfile)) {
    function chocoRefresh {
        Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
        RefreshEnv
    }
}
Remove-Variable _chocoProfile

if ($global:ProfileModules['PSFzf']) {
    function switch_git_branch {
        $branches = git branch -vv | Select-String ': gone]' -NotMatch | ForEach-Object {
            ($_.ToString().Substring(2) -split '\s+')[0]
        }
        $branch = $branches | Sort-Object | Invoke-Fzf -Prompt 'branch> ' -Height 10
        if (-not [String]::IsNullOrEmpty($branch)) {
            Set-Location "$(git rev-parse --show-toplevel)"
            git switch $branch
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }

    function cd_git_worktree {
        $worktrees = @{}
        git worktree list --porcelain | ForEach-Object -Begin {
            $curr = @{}
        } -Process {
            switch -Regex ($_) {
                '^worktree (.+)$' { $curr['Path']   = $matches[1] }
                '^branch (.+)$'   { $curr['Branch'] = $matches[1] -replace '^refs/heads/', '' }
                '^$' {
                    if ($curr['Path'] -and $curr['Branch']) {
                        $worktrees[$curr['Branch']] = $curr['Path']
                        $curr = @{}
                    }
                }
            }
        }
        $selected = $worktrees.Keys | Sort-Object | Invoke-Fzf -Prompt 'worktree> ' -Height 10
        if (-not [String]::IsNullOrEmpty($selected)) {
            Set-Location $worktrees[$selected]
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
}

function Invoke-FzfRipgrep {
    param([string]$Query = '')
    $reload = 'reload:rg --column --color=always --smart-case {q} 2>nul || exit 0'
    $selected = fzf --disabled --ansi --multi `
        --bind "start:$reload" `
        --bind "change:$reload" `
        --bind 'alt-a:select-all,alt-d:deselect-all,ctrl-/:toggle-preview' `
        --delimiter ':' `
        --preview 'bat --style=full --color=always --highlight-line {2} {1}' `
        --preview-window '~4,+{2}+4/3,<80(up)' `
        --prompt 'rg> ' `
        --query $Query
    if (-not $selected) {
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
        return
    }
    $editor = if ($env:EDITOR) { $env:EDITOR } elseif (Get-Command nvim -ErrorAction Ignore) { 'nvim' } else { 'vim' }
    $files = @($selected)
    if ($files.Count -eq 1) {
        $parts = $files[0] -split ':', 3
        & $editor $parts[0] "+$($parts[1])"
    } else {
        $tmpFile = [System.IO.Path]::GetTempFileName()
        try {
            $files | Set-Content $tmpFile
            & $editor '+cw' '-q' $tmpFile
        } finally {
            Remove-Item $tmpFile -ErrorAction Ignore
        }
    }
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}

# --- Hotkey cheatsheet ------------------------------------------------------
function Show-Hotkeys {
    $entries = @(
        '[fzf]    Ctrl+a          select all matches'
        '[fzf]    ?               toggle preview pane'
        '[shell]  Ctrl+r          fuzzy reverse history search'
        '[shell]  Ctrl+t          fuzzy file picker — insert path at cursor'
        '[shell]  Tab             fuzzy tab completion'
        '[shell]  Alt+c           fuzzy directory picker — cd into selection'
        '[shell]  Alt+f           live rg search — rg-filtered, bat preview, multi-select'
        '[shell]  Alt+b           fuzzy git branch switcher'
        '[shell]  Alt+g           fuzzy git worktree navigator'
        '[alias]  rfv / frg       live rg search — rg-filtered, bat preview, multi-select quickfix'
        '[alias]  fe              fuzzy-pick a file and open in $EDITOR'
        '[alias]  fgs             fuzzy git status browser'
        '[alias]  fh              fuzzy command history — paste onto line'
        '[alias]  fkill           fuzzy process picker — kill selection'
        '[alias]  fcd             fuzzy directory picker — cd into selection'
        '[alias]  zi              zoxide interactive directory jump'
        '[nvim]   <leader>ff      find files'
        '[nvim]   <leader>fg      grep in files (ripgrep)'
        '[nvim]   <leader>fb      find open buffers'
        '[nvim]   <leader>fc      find commands'
        '[nvim]   <leader>fl      find lines in loaded buffers'
        '[git]    git a            stage files (add)'
        '[git]    git c            commit'
        '[git]    git co           checkout'
        '[git]    git f            fetch --all --prune'
        '[git]    git s            status --short'
        '[git]    git st           status'
        '[git]    git amend        commit --amend'
        '[git]    git uncommit     undo last commit (reset --mixed HEAD~)'
        '[git]    git unstage      unstage files'
        '[git]    git discard      discard working tree changes'
        '[git]    git staged       diff --staged'
        '[git]    git conflicts    list unmerged files'
        '[git]    git filediff     diff --name-status'
        '[git]    git lg           pretty log graph'
        '[git]    git graph        log graph (50 commits, all refs)'
        '[git]    git last         SHA of last commit'
        '[git]    git branches     branch -a'
        '[git]    git remotes      remote -v'
        '[git]    git stashes      stash list'
        '[git]    git wta          worktree add'
        '[git]    git wtl          worktree list'
        '[git]    git wtr          worktree remove'
        '[git]    git aliases      list all git aliases'
    )
    if (Get-Command Invoke-Fzf -ErrorAction Ignore) {
        $entries | Invoke-Fzf -Prompt 'keys> ' -Height 15
    } elseif (Get-Command fzf -ErrorAction Ignore) {
        $entries | fzf --prompt 'keys> ' --height=15 --no-preview
    } else {
        $entries | Out-Host
    }
}
Set-Alias -Name keys -Value Show-Hotkeys

# --- Environment variables --------------------------------------------------
$env:XDG_CONFIG_HOME = "$HOME/.config"

# Tool config files — paths relative to this repo so they survive repo moves
$_dotfiles = Split-Path $PSScriptRoot
$env:RIPGREP_CONFIG_PATH  = Join-Path $_dotfiles 'ripgrep\ripgreprc'
$env:FZF_DEFAULT_OPTS_FILE = Join-Path $_dotfiles 'fzf\fzfrc'

# Zoxide — store resolved paths so junctions don't produce duplicate entries
$env:_ZO_RESOLVE_SYMLINKS = '1'

# Theme detection — catppuccin mocha (dark) / latte (light), shared by fzf + lazygit
# AppsUseLightTheme: 0x0 = dark, 0x1 = light
$_regOut = reg query 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' /v AppsUseLightTheme 2>$null
$_isDark = $_regOut -match '0x0'

$env:FZF_DEFAULT_OPTS = if ($_isDark) {
    '--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 ' +
    '--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC ' +
    '--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 ' +
    '--color=selected-bg:#45475A --color=border:#6C7086,label:#CDD6F4'
} else {
    '--color=bg+:#CCD0DA,bg:#EFF1F5,spinner:#DC8A78,hl:#D20F39 ' +
    '--color=fg:#4C4F69,header:#D20F39,info:#8839EF,pointer:#DC8A78 ' +
    '--color=marker:#7287FD,fg+:#4C4F69,prompt:#8839EF,hl+:#D20F39 ' +
    '--color=selected-bg:#BCC0CC --color=border:#9CA0B0,label:#4C4F69'
}

# bat preview theme — must match fzf theme so alt+f preview pane doesn't clash
$env:BAT_THEME = if ($_isDark) { 'Catppuccin Mocha' } else { 'Catppuccin Latte' }

# lazygit config — base merged with theme via LG_CONFIG_FILE
$env:LG_CONFIG_FILE = (Join-Path $_dotfiles 'lazygit\config.yml') + ',' + $(if ($_isDark) {
    Join-Path $_dotfiles 'lazygit\theme-mocha.yml'
} else {
    Join-Path $_dotfiles 'lazygit\theme-latte.yml'
})

Remove-Variable _dotfiles, _regOut, _isDark

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

        Set-Alias -Name rfv -Value Invoke-FzfRipgrep -Scope Global
        Set-Alias -Name frg -Value Invoke-FzfRipgrep -Scope Global

        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
        Set-PSReadLineKeyHandler -Chord 'alt+f' -ScriptBlock { Invoke-FzfRipgrep }
        Set-PSReadLineKeyHandler -Chord 'alt+b' -ScriptBlock { switch_git_branch }
        Set-PSReadLineKeyHandler -Chord 'alt+g' -ScriptBlock { cd_git_worktree }

        Set-PsFzfOption `
            -AltCCommand ([ScriptBlock] { param($Location) Set-Location $Location; [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() }) `
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
