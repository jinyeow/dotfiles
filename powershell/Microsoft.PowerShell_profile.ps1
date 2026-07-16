#Requires -Version 7

# ============================================================================
# PowerShell Profile — Optimised for fast startup via deferred loading
# ============================================================================
# Startup phases:
#   Phase 1 (blocking): Module scan, PSReadLine (History only), prompt definition
#   Phase 2 (first prompt): PSFzf, HistoryAndPlugin, zoxide — one-shot via prompt
#   Phase 3 (async): Az context via background runspace (in Set-Prompt.ps1)
# ============================================================================

# --- Terminal capabilities --------------------------------------------------
# Advertise true-colour support so tools like Claude Code and delta use 24-bit
# RGB colours for diffs instead of falling back to indexed-256 palette colours
# (where colour 8 dark-gray is near-invisible on dark Zellij pane backgrounds).
if (-not $env:COLORTERM) { $env:COLORTERM = 'truecolor' }

# Force Zellij's VT input path on Windows so bracketed paste survives. Without
# TERM, Zellij's native-console reader (ReadConsoleInput) decomposes a multi-line
# paste into one Enter per line, so each newline submits (e.g. Claude Code turns
# one paste into several messages). The guard matters: the outer pwsh that
# launches Zellij has no TERM (Windows doesn't set it) so this kicks in there,
# while inside a Zellij pane TERM is already set and is left untouched.
# See docs/zellij-windows-terminal-colors.md §4.
if (-not $env:TERM) { $env:TERM = 'xterm-256color' }

# yazi shells out to file(1) to guess MIME types for files its rules don't match.
# Git for Windows bundles file.exe but doesn't put usr\bin on PATH, so point yazi
# at it directly via YAZI_FILE_ONE (yazi's documented Windows override) rather than
# polluting PATH with all of Git's Unix tools.
if (-not $env:YAZI_FILE_ONE) {
    $fileExe = "$env:ProgramFiles\Git\usr\bin\file.exe"
    if (Test-Path -LiteralPath $fileExe) { $env:YAZI_FILE_ONE = $fileExe }
}

# --- Module availability cache (single scan of PSModulePath) ---------------
$global:ProfileModules = @{}
$modulePaths = $env:PSModulePath -split [IO.Path]::PathSeparator
foreach ($name in @('PSFzf', 'git-completion', 'Az.Accounts', 'Az.Tools.Predictor', 'Microsoft.WinGet.CommandNotFound')) {
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

# Only configure PSReadLine on an interactive, VT-capable host with a live (non-redirected)
# console. Under a redirected/non-interactive load (e.g. `pwsh -Command ...` with output piped,
# or a hook host), -PredictionSource/-PredictionViewStyle emit "predictive suggestions require a
# console that supports virtual terminal" errors. $Host.UI.SupportsVirtualTerminal alone is
# insufficient — it stays true when stdout is captured — so also require a non-redirected stdout.
# The flag is reused to gate the Phase 2a HistoryAndPlugin upgrade.
$global:ProfileInteractiveConsole = [Environment]::UserInteractive -and
    -not [Console]::IsOutputRedirected -and
    ($Host.UI.SupportsVirtualTerminal -eq $true)
if ($global:ProfileInteractiveConsole) {
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
    # Inline-prediction acceptance (the grey ghost text). RightArrow/End accept the WHOLE
    # suggestion (PSReadLine default, unchanged); ForwardChar (Ctrl+f, above) walks one char.
    # Bind Alt+RightArrow to ForwardWord so, at end-of-line, it accepts the next WORD of the
    # suggestion — and elsewhere it is an ordinary word-forward motion. Tab never accepts a
    # prediction: it is a separate subsystem and discards the suggestion to run completion.
    Set-PSReadLineKeyHandler -Chord Alt+RightArrow -Function ForwardWord
    Set-PSReadLineKeyHandler -Chord Ctrl+p -Function PreviousHistory
    Set-PSReadLineKeyHandler -Chord Ctrl+n -Function NextHistory
    Set-PSReadLineKeyHandler -Chord Ctrl+a -Function BeginningOfLine
    Set-PSReadLineKeyHandler -Chord Ctrl+e -Function EndOfLine
    Set-PSReadLineKeyHandler -Chord Ctrl+w -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord Ctrl+u -Function BackwardDeleteLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+?' -ScriptBlock { Show-Hotkeys | Out-Null; [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() }
}

# --- Prompt -----------------------------------------------------------------
. "$(Split-Path -Path $PROFILE)/Profile/Set-Prompt.ps1"

# Native tab-completers for az + zellij are registered in Phase 2b
# (Initialize-DeferredProfileSecondary) — they only matter once you tab-complete,
# so registering them at load just delayed the first prompt.

# --- Aliases ----------------------------------------------------------------
Set-Alias c clear -Force
Set-Alias -Name g -Value git
# A function, not `Set-Alias gcif Get-ChildItem -Force`: -Force there binds to
# Set-Alias (allow-overwrite), NOT to gci, so the alias silently never showed
# hidden files. The wrapper actually forwards -Force (and any extra args) to gci.
function gcif { Get-ChildItem -Force @args }

# --- Functions --------------------------------------------------------------
function Get-IsDarkMode {
    # AppsUseLightTheme: 0 = dark, 1 = light. [Microsoft.Win32.Registry]::GetValue
    # reads in-process; the old `reg query` spawned reg.exe (~37ms). Missing value
    # defaults to 1 (light), matching the old no-match behaviour.
    [Microsoft.Win32.Registry]::GetValue(
        'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',
        'AppsUseLightTheme', 1) -eq 0
}

function gst { git status }
function which ($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}
function Start-AdminSession { Start-Process wt -Verb RunAs }
Set-Alias -Name su -Value Start-AdminSession

# eza helpers (ll/la/lt) are defined in Phase 2a (Initialize-DeferredProfile) —
# the Get-Command -CommandType Application PATH scan is deferred off the load path.

function y {
    $tmp = (New-TemporaryFile).FullName
    yazi.exe @args --cwd-file="$tmp"
    # Coerce to a single string (first line): a multi-line cwd-file would make $cwd an
    # array, and Set-Location/Test-Path -LiteralPath on an array throws.
    $cwd = [string](Get-Content -Path $tmp -Encoding UTF8 -TotalCount 1)
    if ($cwd -and $cwd -ne $PWD.Path -and (Test-Path -LiteralPath $cwd -PathType Container)) {
        Set-Location -LiteralPath (Resolve-Path -LiteralPath $cwd).Path
    }
    Remove-Item -Path $tmp -ErrorAction Ignore
}

if ($global:ProfileModules['PSFzf']) {
    function switch_git_branch {
        $branches = git branch -vv | Select-String ': gone]' -NotMatch | ForEach-Object {
            ($_.ToString().Substring(2) -split '\s+')[0]
        }
        # Bare fzf (native pipeline), NOT PSFzf's Invoke-Fzf: its redirected-stdout
        # System.Diagnostics.Process launcher desyncs under psmux's ConPTY. Fullscreen
        # (no -Height 10 box) is the deliberate, reversible trade for correct rendering.
        $branch = $branches | Sort-Object | fzf --prompt 'branch> '
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
        # Bare fzf (native pipeline), NOT PSFzf's Invoke-Fzf: its redirected-stdout
        # System.Diagnostics.Process launcher desyncs under psmux's ConPTY. Fullscreen
        # (no -Height 10 box) is the deliberate, reversible trade for correct rendering.
        $selected = $worktrees.Keys | Sort-Object | fzf --prompt 'worktree> '
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

function Invoke-Tig {
    # Re-check OS theme on each launch so tig picks up mid-session theme changes
    $env:TIGRC_USER = Join-Path $env:DOTFILES $(if (Get-IsDarkMode) { 'tig\tigrc-mocha' } else { 'tig\tigrc-latte' })
    $env:BAT_THEME  = if (Get-IsDarkMode) { 'Catppuccin Mocha' } else { 'Catppuccin Latte' }
    & (Get-Command tig -CommandType Application -ErrorAction Stop) @args
}
Set-Alias -Name tig -Value Invoke-Tig -Force

function Invoke-Bat {
    # Re-check OS theme on each call so bat picks up mid-session dark/light toggles
    # (BAT_THEME is otherwise resolved once at profile load — see the bat block below)
    $env:BAT_THEME = if (Get-IsDarkMode) { 'Catppuccin Mocha' } else { 'Catppuccin Latte' }
    & (Get-Command bat -CommandType Application -ErrorAction Stop) @args
}
Set-Alias -Name bat -Value Invoke-Bat -Force

# --- Hotkey cheatsheet ------------------------------------------------------
function Show-Hotkeys {
    $entries = @(
        '[fzf]    alt-a / alt-d   select-all / deselect-all (live rg picker)'
        '[fzf]    ctrl-/          toggle preview pane (live rg picker)'
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
        '[eza]    ll              long list with git status + icons'
        '[eza]    la              long list including hidden entries'
        '[eza]    lt              2-level directory tree'
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
    # Prefer the bare `fzf` binary over PSFzf's Invoke-Fzf: this runs from a PSReadLine
    # handler (Ctrl+?), and Invoke-Fzf's redirected-stdout System.Diagnostics.Process
    # launcher desyncs under psmux's ConPTY (the doubled-UI path documented throughout
    # this file). Invoke-Fzf is only the fallback for when the bare binary is absent.
    if (Get-Command fzf -ErrorAction Ignore) {
        $entries | fzf --prompt 'keys> ' --height=15 --no-preview
    } elseif (Get-Command Invoke-Fzf -ErrorAction Ignore) {
        $entries | Invoke-Fzf -Prompt 'keys> ' -Height 15
    } else {
        $entries | Out-Host
    }
}
Set-Alias -Name keys -Value Show-Hotkeys

# --- Environment variables --------------------------------------------------
# Guard like the COLORTERM/TERM guards above — don't clobber a value the user (or a
# parent shell) already set; only provide the default when it is unset.
if (-not $env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME = "$HOME/.config" }

# Tool config files — paths relative to this repo so they survive repo moves
$_dotfiles = Split-Path $PSScriptRoot
$env:DOTFILES = $_dotfiles  # persist so wrapper functions can find theme files at runtime
$env:RIPGREP_CONFIG_PATH  = Join-Path $_dotfiles 'ripgrep\ripgreprc'
$env:FZF_DEFAULT_OPTS_FILE = Join-Path $_dotfiles 'fzf\fzfrc'

# The fd-backed FZF_*_COMMAND vars are set in Phase 2a (Initialize-DeferredProfile),
# alongside PSFzf which consumes them — the Get-Command fd PATH scan is deferred
# off the load path.

# Zoxide — store resolved paths so junctions don't produce duplicate entries
$env:_ZO_RESOLVE_SYMLINKS = '1'

# Theme detection — catppuccin mocha (dark) / latte (light), shared by fzf + lazygit.
# Reuse Get-IsDarkMode (defined above) rather than duplicating the registry read.
$_isDark = Get-IsDarkMode

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

# zoxide's `zi` picker spawns fzf with its own FZF_DEFAULT_OPTS (no colours),
# clobbering the themed env var above. _ZO_FZF_OPTS is appended to that child
# env, so this restores the catppuccin theme on `zi` without losing zoxide's
# structural defaults (layout, preview, height).
$env:_ZO_FZF_OPTS = $env:FZF_DEFAULT_OPTS

# bat config and preview theme — must match fzf theme so alt+f preview pane doesn't clash.
# Load-time default; the `bat` alias (Invoke-Bat) re-checks per call for mid-session toggles.
$env:BAT_CONFIG_PATH = Join-Path $_dotfiles 'bat\config'
$env:BAT_THEME = if ($_isDark) { 'Catppuccin Mocha' } else { 'Catppuccin Latte' }

# lazygit config — base merged with theme via LG_CONFIG_FILE
$env:LG_CONFIG_FILE = (Join-Path $_dotfiles 'lazygit\config.yml') + ',' + $(if ($_isDark) {
    Join-Path $_dotfiles 'lazygit\theme-mocha.yml'
} else {
    Join-Path $_dotfiles 'lazygit\theme-latte.yml'
})

# tig theme — TIGRC_USER overrides ~/.tigrc; theme files source ~/.tigrc for base settings
$env:TIGRC_USER = Join-Path $_dotfiles $(if ($_isDark) { 'tig\tigrc-mocha' } else { 'tig\tigrc-latte' })

# eza theme (catppuccin mauve) — eza reads theme.yml from EZA_CONFIG_DIR, so each
# flavour lives in its own dir; point at the mocha or latte one to match the rest.
$env:EZA_CONFIG_DIR = Join-Path $_dotfiles $(if ($_isDark) { 'eza\themes\mocha' } else { 'eza\themes\latte' })

$env:EDITOR = if (Get-Command nvim -ErrorAction Ignore) {
    'nvim'
} elseif (Get-Command vim -ErrorAction Ignore) {
    'vim'
} elseif (Get-Command code -ErrorAction Ignore) {
    'code'
} elseif ($IsWindows) {
    'notepad'
} else {
    'vi'
}
$env:VISUAL = $env:EDITOR

Remove-Variable _dotfiles, _isDark

# --- Deferred loading (Phase 2a + 2b) --------------------------------------
# Two-stage OnIdle loading: prompt appears immediately, Phase 2a unblocks
# interactive tools (PSFzf, zoxide) on the first idle, then Phase 2b loads
# less-frequently-needed modules (git-completion, WinGet) on the next idle so
# the first keypress isn't delayed by their import cost.
$global:ProfileDeferredDone = $false
$global:ProfileDeferredSecondaryDone = $false

function Initialize-DeferredProfile {
    if ($global:ProfileDeferredDone) { return }
    $global:ProfileDeferredDone = $true

    # PSFzf (~1.1s)
    if ($global:ProfileModules['PSFzf']) {
        Import-Module PSFzf

        # Ctrl+t / Ctrl+r run BARE `fzf` via pwsh's native pipeline, NOT PSFzf's Invoke-Fzf.
        # PSFzf launches fzf through a redirected-stdout System.Diagnostics.Process from inside
        # a PSReadLine handler; under psmux's ConPTY that desyncs fzf's screen/cursor state
        # (doubled UI, corrupt Ctrl+t input, staircased Tab). Bare fullscreen fzf is unaffected.
        function global:Format-FzfPickInsertion {
            [OutputType([string])]
            param([string[]]$Picks)
            # pwsh-quote any pick with whitespace (single-quote, doubling embedded '); join with spaces.
            ($Picks | ForEach-Object {
                if ($_ -match '\s') { "'" + ($_ -replace "'", "''") + "'" } else { $_ }
            }) -join ' '
        }

        function global:Get-FzfDedupedHistory {
            [OutputType([string[]])]
            param([string[]]$Lines)
            # File order is oldest-first; walk backwards for newest-first, keep first sight of each.
            $seen = [System.Collections.Generic.HashSet[string]]::new()
            $result = [System.Collections.Generic.List[string]]::new()
            for ($i = $Lines.Count - 1; $i -ge 0; $i--) {
                if ($seen.Add($Lines[$i])) { $result.Add($Lines[$i]) }
            }
            $result.ToArray()
        }

        function global:Invoke-FzfFilePicker {
            # Ctrl+t: bare fullscreen fzf; insert the pick(s) at the cursor. fzf SELF-POPULATES from
            # its own command — we do NOT pipe a producer in (`fd | fzf`): piping into fzf from a
            # PSReadLine handler renders a doubled UI under psmux, whereas letting fzf spawn the
            # walker itself (like the clean Alt+f picker) is fine. FZF_CTRL_T_COMMAND ==
            # FZF_DEFAULT_COMMAND here, so plain `fzf` uses the fd file-walker.
            $picks = fzf --multi
            if (-not $picks) { return }   # cancel leaves the buffer unchanged
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert((Format-FzfPickInsertion -Picks @($picks)))
        }

        function global:Invoke-FzfHistoryPicker {
            # Ctrl+r: bare fullscreen fzf over PSReadLine history; replace the whole line. fzf must
            # OWN the tty for both its list AND its interaction: piping history in (`$entries | fzf`)
            # from a PSReadLine handler leaves fzf with a piped stdin and no interactive terminal, so
            # it renders NOTHING (and an external-process pipe doubles under psmux). History cannot be
            # walked like files, so stage it to a temp file and let fzf SELF-POPULATE from it via a
            # temporary FZF_DEFAULT_COMMAND override (cmd `type` — the shell fzf uses on Windows).
            $line = ''
            $cursor = 0
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
            $line = [string]$line   # GetBufferState yields '' for an empty buffer; keep it a string
            $historyPath = (Get-PSReadLineOption).HistorySavePath
            # Each file line is treated as one entry; backtick-continued multi-line history
            # entries are a known limitation (handled as separate lines, not stitched).
            $entries = if ($historyPath -and (Test-Path -LiteralPath $historyPath)) {
                Get-FzfDedupedHistory -Lines @(Get-Content -LiteralPath $historyPath)
            } else {
                @()
            }
            if (-not $entries) { return }   # no history to search
            $tmp = [System.IO.Path]::GetTempFileName()
            $prev = $env:FZF_DEFAULT_COMMAND
            try {
                Set-Content -LiteralPath $tmp -Value $entries   # newest-first, one entry per line
                $env:FZF_DEFAULT_COMMAND = "type `"$tmp`""
                # Literal args, NOT a splat. `$x = if (…) { @('--no-sort') }` returns a single-element
                # array that PowerShell unwraps to the scalar string '--no-sort'; `fzf @x` then splats a
                # *string* character-by-character, so fzf sees a bare '-' → "unknown option: -" (exit 2,
                # no UI). Only the empty-buffer branch broke — the 3-element --query branch stays an array.
                # Omit --query on an empty buffer (the common Ctrl+r case): fzf treats it as no filter anyway.
                $pick = if ($line) { fzf --no-sort --query $line } else { fzf --no-sort }
            } finally {
                $env:FZF_DEFAULT_COMMAND = $prev
                Remove-Item -LiteralPath $tmp -ErrorAction Ignore
            }
            if (-not $pick) { return }   # cancel leaves the buffer unchanged
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $pick)
        }

        function global:Invoke-FzfSetLocationPicker {
            # Alt+c: bare fullscreen fzf directory picker; cd to the pick. fzf SELF-POPULATES via a
            # temporary FZF_DEFAULT_COMMAND override (the fd dir-walker) — we do NOT pipe (`fd | fzf`),
            # which renders a doubled UI from a PSReadLine handler under psmux (see Invoke-FzfFilePicker).
            # Cancel just redraws (models PSFzf's AltCCommand: Set-Location then InvokePrompt).
            $prev = $env:FZF_DEFAULT_COMMAND
            try {
                if ($env:FZF_ALT_C_COMMAND) { $env:FZF_DEFAULT_COMMAND = $env:FZF_ALT_C_COMMAND }
                $pick = fzf
            } finally {
                $env:FZF_DEFAULT_COMMAND = $prev
            }
            if ($pick) { Set-Location $pick }
            [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
        }

        Set-Alias -Name rfv -Value Invoke-FzfRipgrep -Scope Global
        Set-Alias -Name frg -Value Invoke-FzfRipgrep -Scope Global

        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
        Set-PSReadLineKeyHandler -Chord 'alt+f' -ScriptBlock { Invoke-FzfRipgrep }
        Set-PSReadLineKeyHandler -Chord 'alt+b' -ScriptBlock { switch_git_branch }
        Set-PSReadLineKeyHandler -Chord 'alt+g' -ScriptBlock { cd_git_worktree }

        # Empty chords tell Set-PsFzfOption not to (re)bind PSFzf's own Ctrl+t / Ctrl+r /
        # Alt+c handlers (SetPsReadlineShortcut skips an empty chord — PSFzf.Base.ps1:881).
        Set-PsFzfOption `
            -PSReadlineChordProvider '' `
            -PSReadlineChordReverseHistory '' `
            -PSReadlineChordSetLocation '' `
            -AltCCommand ([ScriptBlock] { param($Location) Set-Location $Location; [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() }) `
            -EnableAliasFuzzyEdit `
            -EnableAliasFuzzyGitStatus `
            -EnableAliasFuzzyHistory `
            -EnableAliasFuzzyKillProcess `
            -EnableAliasFuzzySetLocation

        # Bind our bare-fzf handlers AFTER Set-PsFzfOption so they win last-write: PSFzf
        # binds Ctrl+t / Ctrl+r / Alt+c to its redirected-stdout handlers at Import-Module
        # (defaults, PSFzf.Base.ps1:2-4), which desync under psmux's ConPTY. Ctrl+r is bound in
        # BOTH Vi key-tables: EditMode is Vi, so a plain (no -ViMode) bind lands only in the Insert
        # table, leaving Command-mode Ctrl+r on the Phase-1 ReverseSearchHistory bind (line ~85) — a
        # split behaviour plus a duplicate row in Get-PSReadLineKeyHandler. Insert is what fires
        # while typing, so overriding both tables makes Ctrl+r = fzf history in either Vi mode.
        Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -ScriptBlock { Invoke-FzfFilePicker }
        Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -ViMode Insert  -BriefDescription FzfHistory -ScriptBlock { Invoke-FzfHistoryPicker }
        Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -ViMode Command -BriefDescription FzfHistory -ScriptBlock { Invoke-FzfHistoryPicker }
        Set-PSReadLineKeyHandler -Chord 'Alt+c' -ScriptBlock { Invoke-FzfSetLocationPicker }
    }

    # fd-backed fzf pickers (moved off Phase 1). PSFzf and bare fzf read these at
    # invocation, so setting them on first idle is in time for the first picker.
    if (Get-Command -Name fd -CommandType Application -ErrorAction Ignore) {
        # --exclude AppData/node_modules: from ~ the walk is dominated by AppData (100k+ dirs on
        # Windows) and node_modules; excluding them keeps Ctrl+t/Alt+c fast. fd already honours
        # .gitignore, so node_modules inside a repo is skipped anyway — this covers the non-repo case.
        $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git --exclude node_modules --exclude AppData'
        $env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
        $env:FZF_ALT_C_COMMAND   = 'fd --type d --hidden --exclude .git --exclude node_modules --exclude AppData'
    }

    # eza listing helpers (moved off Phase 1). Defined global: so they reach the
    # session scope — a bare `function ll` here would be local to this function.
    if (Get-Command -Name eza -CommandType Application -ErrorAction Ignore) {
        function global:ll { eza --long --git --icons=auto --group-directories-first @args }
        function global:la { eza --long --git --icons=auto --group-directories-first --all @args }
        function global:lt { eza --tree --level=2 --icons=auto --git-ignore @args }
    }

    # Az context timer (moved off Phase 1 — runspace.Open() + eventing ~115ms).
    # Defined in Set-Prompt.ps1, dot-sourced in Phase 1; self-guards on Az.Accounts.
    Initialize-AzTimer

    # Upgrade prediction source to include Az.Tools.Predictor plugin (~650ms).
    # Gated on the same interactive/VT-capable check as the Phase 1 PSReadLine setup.
    if ($global:ProfileInteractiveConsole -and $global:ProfileModules['Az.Tools.Predictor']) {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    }

    # Zoxide (~340ms) — --hook none: zoxide's default hook wraps $function:prompt,
    # but Phase 1 redefines the prompt on every reload and the deferred-once guard
    # blocks re-wrapping, so the wrapper detaches after `. $PROFILE` and recording
    # silently stops. With --hook none the custom prompt records directories itself
    # (see Set-Prompt.ps1), which survives reloads and keeps $LASTEXITCODE intact.
    if (Get-Command -Name zoxide -ErrorAction Ignore) {
        Invoke-Expression (& { (zoxide init powershell --hook none | Out-String) })
    }
}

function Initialize-DeferredProfileSecondary {
    if ($global:ProfileDeferredSecondaryDone) { return }
    $global:ProfileDeferredSecondaryDone = $true

    # Native tab-completers (moved off Phase 1 — only needed once you tab-complete)
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
    if (Get-Command -Name zellij -ErrorAction Ignore) {
        Register-ArgumentCompleter -Native -CommandName zellij -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $sessionCmds = 'attach', 'a', 'kill-session', 'k', 'delete-session', 'd'
            $elements = $commandAst.CommandElements
            if ($elements.Count -ge 2 -and $elements[1].Value -in $sessionCmds) {
                zellij list-sessions --no-formatting 2>$null |
                    ForEach-Object { ($_ -split '\s+')[0] } |
                    Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object {
                        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                    }
            }
        }
    }

    # psmux (native-Windows tmux) — fzf session pickers + name completion. psmux aliases as
    # psmux/pmux/tmux; only wire this up when it is actually installed.
    if (Get-Command -Name psmux -ErrorAction Ignore) {
        # global: — a bare `function` here would be local to Initialize-DeferredProfileSecondary.
        function global:Get-PsmuxSession { psmux list-sessions -F '#{session_name}' 2>$null }

        # Attach to an fzf-picked session — switch-client if already inside psmux (attach can't nest).
        function global:Enter-PsmuxSession {
            $target = Get-PsmuxSession | fzf --prompt 'psmux attach> ' --height 40% --reverse
            if (-not $target) { return }
            if ($env:PSMUX_TARGET_SESSION) { psmux switch-client -t $target } else { psmux attach -t $target }
        }

        # Kill one or more fzf-picked sessions (multi-select with Tab).
        function global:Remove-PsmuxSession {
            Get-PsmuxSession | fzf --prompt 'psmux kill> ' --height 40% --reverse --multi |
                ForEach-Object { psmux kill-session -t $_ }
        }

        Register-ArgumentCompleter -Native -CommandName psmux, pmux, tmux -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $elements = $commandAst.CommandElements
            # Completing the subcommand itself (`psmux <TAB>` / `psmux a<TAB>`): offer command
            # names + aliases from list-commands (works without a running server).
            if ($elements.Count -eq 1 -or ($elements.Count -eq 2 -and $wordToComplete)) {
                psmux list-commands 2>$null |
                    ForEach-Object { if ($_ -match '^\s+(\S+)(?:\s+\(([^)]+)\))?') { $Matches[1]; if ($Matches[2]) { $Matches[2] } } } |
                    Where-Object { $_ -like "$wordToComplete*" } |
                    Sort-Object -Unique |
                    ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
                return
            }
            # Completing an argument after a session-targeting subcommand: offer session names.
            $sessionCmds = 'attach', 'attach-session', 'a', 'kill-session', 'switch-client', 'switchc', 'has-session'
            if ($elements[1].Value -in $sessionCmds) {
                psmux list-sessions -F '#{session_name}' 2>$null |
                    Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object {
                        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                    }
            }
        }
    }

    # git-completion
    if ($global:ProfileModules['git-completion']) {
        Import-Module git-completion
        Register-ArgumentCompleter -Native -CommandName g -ScriptBlock ${Function:Complete-Git}
    }

    # WinGet CommandNotFound (~1.4s — .NET assembly loading)
    if ($global:ProfileModules['Microsoft.WinGet.CommandNotFound']) {
        Import-Module -Name Microsoft.WinGet.CommandNotFound
    }
}

# Fire deferred loading on first idle.
# OnIdle fires repeatedly (~2x/sec), but Initialize-DeferredProfile guards
# with $global:ProfileDeferredDone and returns immediately after the first run.
# Phase 2a fires on first idle; 2b fires on the next idle after 2a completes.
# Both guards are booleans so . $PROFILE reloads stay idempotent.
Get-EventSubscriber -ErrorAction SilentlyContinue |
    Where-Object { $_.SourceIdentifier -eq 'PowerShell.OnIdle' -and $_.Action.Command -match 'DeferredProfile' } |
    Unregister-Event
Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -Action {
    if (-not $global:ProfileDeferredDone) {
        Initialize-DeferredProfile
    } elseif (-not $global:ProfileDeferredSecondaryDone) {
        Initialize-DeferredProfileSecondary
    } else {
        # Both phases done — OnIdle fires ~2x/sec forever otherwise, running this
        # no-op indefinitely. Self-unregister once there is nothing left to do.
        # $EventSubscriber is the automatic var for the currently-firing subscriber;
        # the reload-idempotency unregister above still covers `. $PROFILE`.
        Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId -ErrorAction Ignore
    }
} | Out-Null
