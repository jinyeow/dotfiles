#Requires -Version 7
<#
.SYNOPSIS
    Install dotfiles on Windows.

.DESCRIPTION
    Creates junctions, stubs, or copies to wire the dotfiles repo into the
    correct OS locations. Safe to re-run — existing targets are backed up
    before being replaced.

.PARAMETER Module
    One or more modules to install: neovim, vim, powershell, git, bash, tig, tmux, zellij, yazi, curl, claude, codex, lazygit, windowsterminal, bat, vscode, winget, all.
    Optional when -CleanBackups is specified.

.PARAMETER DryRun
    Preview what would happen without making any changes.

.PARAMETER Backup
    Reverse-sync: pull each module's live copied files (e.g. ~/.claude/CLAUDE.md)
    back INTO the repo, capturing drift before a normal run would overwrite them.
    Only copied files are synced — junctions and stubs reference the repo directly
    and cannot drift, so they are skipped. Git is the review/safety net: nothing is
    overwritten silently — inspect with `git diff` and commit what you want to keep.

.PARAMETER CleanBackups
    Remove old backup files (.bak.TIMESTAMP) left by previous runs.

.PARAMETER KeepBackups
    When -CleanBackups is set: keep this many of the most recent backups per file. Default: 5. 0 = no limit.

.PARAMETER MaxBackupAgeDays
    When -CleanBackups is set: delete backups older than this many days. Default: 0 (disabled).

.EXAMPLE
    .\setup.ps1 -Module neovim,powershell
    .\setup.ps1 -Module git
    .\setup.ps1 -Module all -DryRun
    .\setup.ps1 -Module claude -Backup
    .\setup.ps1 -Module all -Backup -DryRun
    .\setup.ps1 -CleanBackups
    .\setup.ps1 -CleanBackups -KeepBackups 3
    .\setup.ps1 -Module git -CleanBackups -MaxBackupAgeDays 30
#>
param(
    [string[]] $Module = @(),

    [switch] $DryRun,

    [switch] $Backup,

    [switch] $CleanBackups,
    [int] $KeepBackups = 5,
    [int] $MaxBackupAgeDays = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Dotfiles = $PSScriptRoot

# Expand 'all'
if ($Module -contains 'all') {
    $Module = @('neovim', 'vim', 'powershell', 'git', 'bash', 'tig', 'tmux', 'zellij', 'yazi', 'curl', 'claude', 'codex', 'lazygit', 'windowsterminal', 'bat', 'vscode', 'winget')
}
$Module = $Module | Select-Object -Unique

# ── Output helpers ────────────────────────────────────────────────────────────

function Write-Info    ($Msg) { Write-Host "[INFO]  $Msg" -ForegroundColor Cyan    }
function Write-Ok      ($Msg) { Write-Host "[OK]    $Msg" -ForegroundColor Green   }
function Write-Warn    ($Msg) { Write-Host "[WARN]  $Msg" -ForegroundColor Yellow  }
function Write-Fail    ($Msg) { Write-Host "[ERROR] $Msg" -ForegroundColor Red     }

# ── Core helpers ──────────────────────────────────────────────────────────────

function Backup-Existing ([string]$Path) {
    if (-not (Test-Path $Path)) { return }
    $ts     = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backup = "${Path}.bak.${ts}"
    if (-not $DryRun) { Move-Item -Path $Path -Destination $backup }
    Write-Warn "Backed up:  $Path"
    Write-Warn "        ->  $backup"
}

# Directory junction — works cross-volume, no elevation required.
function New-Junction ([string]$Link, [string]$Target) {
    if ($Backup) { Write-Info "Skipped (linked, no drift):  $Link"; return }
    if (-not (Test-Path $Target -PathType Container)) {
        Write-Fail "Source directory not found: $Target"; return
    }

    # Idempotent: if the link already exists as a junction pointing at $Target, leave it.
    # Without this, re-running a module backs the link up to a .bak.TIMESTAMP junction and
    # recreates it on every run — churn that also pollutes ~/.claude/skills/ with stale
    # backup junctions (which -CleanBackups can't prune, since it only scans files).
    if (Test-Path $Link) {
        $existing = Get-Item $Link -Force -ErrorAction SilentlyContinue
        if ($existing -and ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            $curTarget = if ($existing.LinkTarget) { $existing.LinkTarget } else { @($existing.Target)[0] }
            if ($curTarget) {
                $a = [IO.Path]::GetFullPath($curTarget).TrimEnd('\')
                $b = [IO.Path]::GetFullPath($Target).TrimEnd('\')
                if ([string]::Equals($a, $b, [StringComparison]::OrdinalIgnoreCase)) {
                    Write-Ok "Junction:   $Link (already current)"
                    return
                }
            }
        }
    }

    if ($DryRun) { Write-Info "[DRY RUN] junction $Link -> $Target"; return }

    Backup-Existing $Link
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    Write-Ok "Junction:   $Link"
    Write-Ok "         -> $Target"
}

# File copy — simple, always works cross-volume.
# Re-run the installer to pick up changes from the repo.
# With -Backup, runs in reverse: pulls the live copy ($Dest) back into the repo ($Source).
function Copy-Dotfile ([string]$Dest, [string]$Source) {
    if ($Backup) {
        # Reverse-sync: live copy ($Dest) -> repo ($Source). Only copied files drift
        # (junctions/stubs point at the repo), so this is where drift is captured. Git is
        # the review/safety net — no .bak is written into the repo. Review with `git diff`.
        if (-not (Test-Path $Dest)) {
            Write-Warn "No live file to back up: $Dest"; return
        }
        if ($DryRun) { Write-Info "[DRY RUN] backup (live -> repo) $Dest -> $Source"; return }
        Copy-Item -Path $Dest -Destination $Source -Force
        Write-Ok "Backed up:  $Dest"
        Write-Ok "         -> $Source"
        return
    }
    if (-not (Test-Path $Source)) {
        Write-Fail "Source file not found: $Source"; return
    }
    $dir = Split-Path $Dest
    if (-not (Test-Path $dir)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Write-Info "Created:    $dir"
    }
    if ($DryRun) { Write-Info "[DRY RUN] copy $Source -> $Dest"; return }

    Backup-Existing $Dest
    Copy-Item -Path $Source -Destination $Dest -Force
    Write-Ok "Copied:     $Dest"
    Write-Warn "(Re-run setup.ps1 after editing this file in the repo)"
}

# Generated stub — sources the real PS file from the repo path.
# Changes to the repo file are live immediately; no elevation needed.
function New-SourceStub ([string]$StubPath, [string]$RealSource) {
    if ($Backup) { Write-Info "Skipped (stub, no drift):    $StubPath"; return }
    if (-not (Test-Path $RealSource)) {
        Write-Fail "Source file not found: $RealSource"; return
    }
    $dir = Split-Path $StubPath
    if (-not (Test-Path $dir)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Write-Info "Created:    $dir"
    }
    $content = @"
# Auto-generated by setup.ps1 — do not edit directly.
# Edit the source file in the dotfiles repo and re-run setup.ps1 if the path changes.
. '$RealSource'
"@
    if ($DryRun) { Write-Info "[DRY RUN] stub $StubPath -> $RealSource"; return }

    Backup-Existing $StubPath
    Set-Content -Path $StubPath -Value $content -Encoding UTF8
    Write-Ok "Stub:       $StubPath"
    Write-Ok "         -> $RealSource"
}

# Git [include] stub — installs a gitconfig that includes the real file from the
# repo via git's native include mechanism. Works cross-volume; changes are live.
function New-GitIncludeStub ([string]$StubPath, [string]$RealSource) {
    if ($Backup) { Write-Info "Skipped (stub, no drift):    $StubPath"; return }
    if (-not (Test-Path $RealSource)) {
        Write-Fail "Source file not found: $RealSource"; return
    }
    $dir = Split-Path $StubPath
    if (-not (Test-Path $dir)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Write-Info "Created:    $dir"
    }
    # Git config paths use forward slashes on all platforms.
    $fwdSlashSource = $RealSource.Replace('\', '/')
    $content = @"
; Auto-generated by setup.ps1 — do not edit directly.
; Edit the source file in the dotfiles repo.
[include]
    path = $fwdSlashSource
"@
    if ($DryRun) { Write-Info "[DRY RUN] git-include stub $StubPath -> $RealSource"; return }

    Backup-Existing $StubPath
    Set-Content -Path $StubPath -Value $content -Encoding UTF8
    Write-Ok "Git stub:   $StubPath"
    Write-Ok "         -> $RealSource"
}

# ── Modules ───────────────────────────────────────────────────────────────────

function Install-Git {
    Write-Host ''
    Write-Info '=== Git ==='

    # ~/.gitconfig — stub that [include]s the repo file; cross-volume, always live.
    $params = @{
        StubPath = Join-Path $env:USERPROFILE '.gitconfig'
        RealSource = Join-Path $Dotfiles 'git\gitconfig'
    }
    New-GitIncludeStub @params

    # ~/.gitconfig-work — referenced by [includeIf] inside gitconfig.
    $params = @{
        StubPath = Join-Path $env:USERPROFILE '.gitconfig-work'
        RealSource = Join-Path $Dotfiles 'git\gitconfig-work'
    }
    New-GitIncludeStub @params

    # ~/.gitignore — global ignore file. Copied (not a git [include] stub): gitignore
    # has no include mechanism, so git would read the stub text as ignore patterns.
    $params = @{
        Dest = Join-Path $env:USERPROFILE '.gitignore'
        Source = Join-Path $Dotfiles 'git\gitignore'
    }
    Copy-Dotfile @params

    # ~/.gitignore-work — extra ignore patterns for work repos (overrides core.excludesFile via gitconfig-work).
    $params = @{
        Dest = Join-Path $env:USERPROFILE '.gitignore-work'
        Source = Join-Path $Dotfiles 'git\gitignore-work'
    }
    Copy-Dotfile @params

    # ~/.gitmessage — commit message template.
    $params = @{
        Dest = Join-Path $env:USERPROFILE '.gitmessage'
        Source = Join-Path $Dotfiles 'git\gitmessage'
    }
    Copy-Dotfile @params

    # ~/.git_templates — hooks directory (init.templatedir + core.hooksPath).
    $params = @{
        Link = Join-Path $env:USERPROFILE '.git_templates'
        Target = Join-Path $Dotfiles 'git\templates'
    }
    New-Junction @params
}

function Install-Neovim {
    Write-Host ''
    Write-Info '=== Neovim ==='
    # Honour XDG_CONFIG_HOME if set (the PowerShell profile exports it as ~/.config).
    $configBase = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { $env:LOCALAPPDATA }
    $params = @{
        Link = Join-Path $configBase 'nvim'
        Target = Join-Path $Dotfiles 'nvim'
    }
    New-Junction @params
}

function Install-Vim {
    Write-Host ''
    Write-Info '=== Vim ==='
    # vimrc lives inside vim/ so Vim finds it at ~/vimfiles/vimrc automatically.
    $params = @{
        Link = Join-Path $env:USERPROFILE 'vimfiles'
        Target = Join-Path $Dotfiles 'vim'
    }
    New-Junction @params
}

function Install-PowerShell {
    Write-Host ''
    Write-Info '=== PowerShell ==='

    # Purely linked: profile stubs source the repo and Profile\ is a junction — nothing copied,
    # nothing to drift, so a backup run has nothing to capture here.
    if ($Backup) { Write-Info 'PowerShell is stub + junction — no copied files to back up.'; return }

    $docs = [Environment]::GetFolderPath('MyDocuments')

    # Persist the dotfiles root as a user-scoped env var so the stub below can
    # resolve it at load time rather than baking an absolute path into the file.
    # Re-running setup.ps1 is all that's needed if the repo moves.
    if ($DryRun) {
        Write-Info "[DRY RUN] would set DOTFILES=$Dotfiles (User env var)"
    } else {
        [Environment]::SetEnvironmentVariable('DOTFILES', $Dotfiles, 'User')
        Write-Ok "Env var:    DOTFILES = $Dotfiles  (User scope)"
    }

    # Stub into PS7, PS5, and VSCode locations.
    # Resolves the repo path via $env:DOTFILES at load time — no hardcoded path.
    $stubContent = @'
# Auto-generated by setup.ps1 — do not edit directly.
# Re-run setup.ps1 -Module powershell if the dotfiles path changes.
. (Join-Path $env:DOTFILES 'powershell\Microsoft.PowerShell_profile.ps1')
'@

    $profileTargets = @(
        (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'),        # PS7
        (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'), # PS5
        (Join-Path $docs 'WindowsPowerShell\Microsoft.VSCode_profile.ps1')      # VSCode
    )
    foreach ($target in $profileTargets) {
        $dir = Split-Path $target
        if (-not (Test-Path $dir)) {
            if (-not $DryRun) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Write-Info "Created:    $dir"
        }
        if ($DryRun) { Write-Info "[DRY RUN] stub $target -> `$env:DOTFILES\powershell\..."; continue }
        Backup-Existing $target
        Set-Content -Path $target -Value $stubContent -Encoding UTF8
        Write-Ok "Stub:       $target"
        Write-Ok "         -> `$env:DOTFILES\powershell\Microsoft.PowerShell_profile.ps1"
    }

    # Junction the Profile\ subdirectory (contains Set-Prompt.ps1)
    $profileDirSrc  = Join-Path $Dotfiles 'powershell\Profile'
    $profileDirDest = Join-Path $docs 'PowerShell\Profile'
    if (Test-Path $profileDirSrc -PathType Container) {
        New-Junction -Link $profileDirDest -Target $profileDirSrc
    }
}

function Install-Bash {
    Write-Host ''
    Write-Info '=== Bash ==='
    Write-Warn 'Bash module is Linux/WSL only — skipping on Windows.'
}

function Install-Tig {
    Write-Host ''
    Write-Info '=== Tig ==='
    $params = @{
        Dest = Join-Path $env:USERPROFILE '.tigrc'
        Source = Join-Path $Dotfiles 'tig\tigrc'
    }
    Copy-Dotfile @params
    $params = @{
        Dest = Join-Path $env:USERPROFILE '.tigrc.vim'
        Source = Join-Path $Dotfiles 'tig\tigrc.vim'
    }
    Copy-Dotfile @params
}

function Install-Tmux {
    Write-Host ''
    Write-Info '=== Tmux ==='
    Write-Warn 'Tmux module is Linux/WSL only — skipping on Windows.'
}

function Install-Zellij {
    Write-Host ''
    Write-Info '=== Zellij ==='
    # Windows-native path: %APPDATA%\Zellij\config\ (https://zellij.dev/documentation/configuration.html)
    # Zellij does not document XDG support on Windows, so we always use APPDATA here.
    $zellijConfig = Join-Path $env:APPDATA 'Zellij\config'
    $zellijParent = Join-Path $env:APPDATA 'Zellij'
    if (-not (Test-Path $zellijParent) -and -not $DryRun) {
        New-Item -ItemType Directory -Path $zellijParent -Force | Out-Null
        Write-Info "Created:    $zellijParent"
    }
    $params = @{
        Link = $zellijConfig
        Target = Join-Path $Dotfiles 'zellij'
    }
    New-Junction @params
}

function Install-Yazi {
    Write-Host ''
    Write-Info '=== Yazi ==='
    $yaziConfig = Join-Path $env:APPDATA 'yazi\config'
    $yaziParent = Join-Path $env:APPDATA 'yazi'
    if (-not (Test-Path $yaziParent) -and -not $DryRun) {
        New-Item -ItemType Directory -Path $yaziParent -Force | Out-Null
        Write-Info "Created:    $yaziParent"
    }
    $params = @{
        Link = $yaziConfig
        Target = Join-Path $Dotfiles 'yazi'
    }
    New-Junction @params
    if (-not (Get-Command -Name yazi -ErrorAction Ignore)) {
        Write-Warn 'yazi not found. Install with: winget install sxyazi.yazi'
    } else {
        Write-Ok 'yazi is installed.'
    }
    Write-Info 'After setup, install flavors:'
    Write-Info '  ya pkg add yazi-rs/flavors:catppuccin-mocha'
    Write-Info '  ya pkg add yazi-rs/flavors:catppuccin-latte'
}

function Install-Curl {
    Write-Host ''
    Write-Info '=== Curl ==='
    $params = @{
        Dest = Join-Path $env:USERPROFILE '.curlrc'
        Source = Join-Path $Dotfiles 'curl\curlrc'
    }
    Copy-Dotfile @params
}

function Install-WindowsTerminal {
    Write-Host ''
    Write-Info '=== Windows Terminal ==='
    $wtState = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
    if (-not (Test-Path $wtState)) {
        Write-Warn 'Windows Terminal not found — skipping.'
        return
    }
    $params = @{
        Dest = Join-Path $wtState 'settings.json'
        Source = Join-Path $Dotfiles 'windowsterminal\settings.json'
    }
    Copy-Dotfile @params
}

function Install-Lazygit {
    Write-Host ''
    Write-Info '=== Lazygit ==='
    Write-Info 'Config is loaded via $env:LG_CONFIG_FILE set in the PowerShell profile — no files to copy.'
    Write-Info "Base:  $(Join-Path $Dotfiles 'lazygit\config.yml')"
    Write-Info "Theme: lazygit\theme-mocha.yml or theme-latte.yml (selected at profile load from OS theme)"
    if (-not (Get-Command -Name lazygit -ErrorAction Ignore)) {
        Write-Warn 'lazygit not found. Install with: winget install JesseDuffield.lazygit'
    } else {
        Write-Ok 'lazygit is installed.'
    }
}

function Install-Winget {
    Write-Host ''
    Write-Info '=== winget packages ==='
    Write-Info 'Run the bootstrap script to install curated packages on a new machine:'
    Write-Info "  $(Join-Path $Dotfiles 'winget\packages.ps1') [-DryRun]"
    Write-Info 'Or use winget import:'
    Write-Info "  winget import -i $(Join-Path $Dotfiles 'winget\packages.json') --ignore-unavailable"
}

function Install-VSCode {
    Write-Host ''
    Write-Info '=== VSCode ==='
    Write-Info 'Settings are managed by VSCode Settings Sync — no files to copy.'
    Write-Info "Reference snapshot: $(Join-Path $Dotfiles 'vscode\settings.json')"
    Write-Info 'Machine-specific settings (not synced) must be configured locally:'
    Write-Info '  vscode-neovim.neovimExecutablePaths.win32'
    Write-Info '  powershell.powerShellAdditionalExePaths'
    Write-Info '  dotnetAcquisitionExtension.existingDotnetPath'
    Write-Info '  dev.containers.dockerPath'
    Write-Info '  mssql.connections / mssql.connectionGroups'
    Write-Info '  github-actions.use-enterprise'
    if (-not (Get-Command -Name code -ErrorAction Ignore)) {
        Write-Warn 'VSCode not found in PATH. Install from https://code.visualstudio.com/'
    } else {
        Write-Ok 'VSCode is installed.'
    }
}

function Install-Bat {
    Write-Host ''
    Write-Info '=== bat ==='
    Write-Info 'Config is loaded via $env:BAT_CONFIG_PATH set in the PowerShell profile — no files to copy.'
    Write-Info "Config: $(Join-Path $Dotfiles 'bat\config')"
    if (-not (Get-Command -Name bat -ErrorAction Ignore)) {
        Write-Warn 'bat not found. Install with: winget install sharkdp.bat'
    } else {
        Write-Ok 'bat is installed.'
    }
}

function Install-Claude {
    Write-Host ''
    Write-Info '=== Claude Code ==='
    $claudeDir = Join-Path $env:USERPROFILE '.claude'
    $params = @{
        Dest = Join-Path $claudeDir 'settings.json'
        Source = Join-Path $Dotfiles 'claude\settings.json'
    }
    Copy-Dotfile @params
    $params = @{
        Dest = Join-Path $claudeDir 'CLAUDE.md'
        Source = Join-Path $Dotfiles 'claude\CLAUDE.md'
    }
    Copy-Dotfile @params
    # Shared coding conventions. CLAUDE.md imports this via `@AGENTS.md` (resolves to
    # ~/.claude/AGENTS.md). The codex module installs the same source to ~/.codex/AGENTS.md.
    $params = @{
        Dest = Join-Path $claudeDir 'AGENTS.md'
        Source = Join-Path $Dotfiles 'claude\AGENTS.md'
    }
    Copy-Dotfile @params
    $params = @{
        Dest = Join-Path $claudeDir 'statusline-command.sh'
        Source = Join-Path $Dotfiles 'claude\statusline-command.sh'
    }
    Copy-Dotfile @params

    # Skills — junction each subdirectory into ~/.claude/skills/
    $skillsSrc = Join-Path $Dotfiles 'claude\skills'
    $skillsDst = Join-Path $claudeDir 'skills'
    if (-not (Test-Path $skillsDst)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null }
        Write-Info "Created:    $skillsDst"
    }
    $skills = Get-ChildItem -Path $skillsSrc -Directory -ErrorAction SilentlyContinue
    if ($skills) {
        foreach ($skill in $skills) {
            New-Junction -Link (Join-Path $skillsDst $skill.Name) -Target $skill.FullName
        }
    } else {
        Write-Info 'No skills to install (claude/skills/ is empty).'
    }
}

function Install-Codex {
    Write-Host ''
    Write-Info '=== Codex CLI ==='

    # 1. Install the Codex CLI via OpenAI's native installer (self-updating), mirroring the
    #    claude module's native-install decision. Skip if already present.
    if ($Backup) {
        Write-Info 'Backup mode — skipping Codex CLI install.'
    } elseif (Get-Command -Name codex -ErrorAction Ignore) {
        Write-Ok 'codex is already installed.'
    } elseif ($DryRun) {
        Write-Info '[DRY RUN] would install Codex CLI via native installer (https://chatgpt.com/codex/install.ps1)'
    } else {
        Write-Info 'Installing Codex CLI (native installer)...'
        $installer = Join-Path $env:TEMP 'codex-install.ps1'
        Invoke-RestMethod -Uri 'https://chatgpt.com/codex/install.ps1' -OutFile $installer
        & $installer
        Remove-Item -Path $installer -Force -ErrorAction Ignore
        if (Get-Command -Name codex -ErrorAction Ignore) {
            Write-Ok 'codex installed.'
        } else {
            Write-Warn 'codex not on PATH yet — open a new shell, or re-run this module, before using it.'
        }
    }

    # 2. Global config: standalone posture (workspace-write + on-request).
    $codexDir = Join-Path $env:USERPROFILE '.codex'
    $params = @{
        Dest = Join-Path $codexDir 'config.toml'
        Source = Join-Path $Dotfiles 'codex\config.toml'
    }
    Copy-Dotfile @params

    # 3. Shared conventions — same source the claude module installs to ~/.claude/AGENTS.md.
    $params = @{
        Dest = Join-Path $codexDir 'AGENTS.md'
        Source = Join-Path $Dotfiles 'claude\AGENTS.md'
    }
    Copy-Dotfile @params

    # 4. Register Codex as a user-scope, read-only MCP reviewer in Claude Code. User-scope MCP
    #    config lives in ~/.claude.json (settings.json does not support mcpServers), so this is
    #    a CLI registration, not a tracked file. The -c overrides pin the reviewer read-only and
    #    non-interactive regardless of ~/.codex/config.toml. Idempotent: remove any prior entry first.
    if ($Backup) {
        Write-Info 'Backup mode — skipping MCP registration.'
    } elseif (-not (Get-Command -Name claude -ErrorAction Ignore)) {
        Write-Warn 'claude CLI not found — skipping MCP registration. Install the claude module first.'
    } elseif ($DryRun) {
        Write-Info '[DRY RUN] would register user-scope MCP: claude mcp add --scope user codex -- codex mcp-server -c sandbox_mode=read-only -c approval_policy=never'
    } else {
        # Native command: a non-zero exit when no prior entry exists is benign and does not throw.
        & claude mcp remove --scope user codex 2>$null | Out-Null
        & claude mcp add --scope user --transport stdio codex -- codex mcp-server -c sandbox_mode=read-only -c approval_policy=never
        if ($LASTEXITCODE -eq 0) {
            Write-Ok 'Registered read-only Codex MCP reviewer (user scope).'
        } else {
            Write-Fail "claude mcp add failed (exit $LASTEXITCODE)."
        }
    }

    Write-Info 'Next: run `codex login` (interactive ChatGPT-account OAuth) to authenticate.'
}

function Remove-OldBackups {
    Write-Host ''
    Write-Info '=== Cleaning backups ==='

    if ($KeepBackups -eq 0 -and $MaxBackupAgeDays -eq 0) {
        Write-Warn '-KeepBackups 0 and -MaxBackupAgeDays 0 — nothing to prune.'
        return
    }

    $docs = [Environment]::GetFolderPath('MyDocuments')
    $configBase = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { $env:LOCALAPPDATA }

    $searchDirs = @(
        $env:USERPROFILE,
        (Join-Path $docs 'PowerShell'),
        (Join-Path $docs 'WindowsPowerShell'),
        (Join-Path $configBase 'nvim'),
        (Join-Path $env:USERPROFILE '.claude'),
        (Join-Path $env:USERPROFILE '.codex'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState')
    ) | Where-Object { Test-Path $_ -PathType Container }

    $allBackups = @(foreach ($dir in $searchDirs) {
        Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '\.bak\.(\d{8}_\d{6})$' }
    })

    if ($allBackups.Count -eq 0) { Write-Info 'No backup files found.'; return }

    $cutoff = if ($MaxBackupAgeDays -gt 0) { (Get-Date).AddDays(-$MaxBackupAgeDays) } else { $null }
    $removed = 0
    $groups = $allBackups | Group-Object { $_.FullName -replace '\.bak\.\d{8}_\d{6}$', '' }

    foreach ($group in $groups) {
        $sorted = @($group.Group | Sort-Object Name -Descending)  # newest first

        for ($i = 0; $i -lt $sorted.Count; $i++) {
            $file = $sorted[$i]
            $removeByCount = $KeepBackups -gt 0 -and $i -ge $KeepBackups
            $removeByAge = $false
            if ($cutoff -and $file.Name -match '\.bak\.(\d{8}_\d{6})$') {
                $ts = [datetime]::ParseExact($Matches[1], 'yyyyMMdd_HHmmss', $null)
                $removeByAge = $ts -lt $cutoff
            }

            if (-not ($removeByCount -or $removeByAge)) { continue }

            $reason = if ($removeByAge) { 'age' } else { 'count' }
            if ($DryRun) {
                Write-Info "[DRY RUN] would remove ($reason): $($file.FullName)"
            } else {
                Remove-Item -Path $file.FullName -Force
                Write-Ok "Removed ($reason): $($file.FullName)"
            }
            $removed++
        }
    }

    if ($removed -eq 0) { Write-Info 'Nothing to prune.' }
}

# ── Main ─────────────────────────────────────────────────────────────────────

if ($Module.Count -eq 0 -and -not $CleanBackups) {
    Write-Fail "Specify -Module <modules> and/or -CleanBackups. Run 'Get-Help .\setup.ps1' for usage."
    exit 1
}

if ($DryRun) { Write-Warn 'DRY RUN — no changes will be made.' }
if ($Backup) { Write-Warn 'BACKUP MODE — pulling live copies back into the repo. Review with `git diff` before committing.' }

foreach ($m in $Module) {
    switch ($m) {
        'neovim'     { Install-Neovim     }
        'vim'        { Install-Vim        }
        'powershell' { Install-PowerShell }
        'git'        { Install-Git        }
        'bash'       { Install-Bash       }
        'tig'        { Install-Tig        }
        'tmux'       { Install-Tmux       }
        'zellij'     { Install-Zellij     }
        'yazi'       { Install-Yazi       }
        'curl'       { Install-Curl       }
        'winget'     { Install-Winget     }
        'vscode'     { Install-VSCode     }
        'bat'        { Install-Bat        }
        'claude'     { Install-Claude     }
        'codex'      { Install-Codex      }
        'lazygit'        { Install-Lazygit        }
        'windowsterminal' { Install-WindowsTerminal }
        default          { Write-Warn "Unknown module '$m' — skipping." }
    }
}

if ($CleanBackups) { Remove-OldBackups }

Write-Host ''
Write-Ok 'Done.'
if ($Backup -and -not $DryRun) { Write-Info "Review the captured drift: git -C `"$Dotfiles`" diff" }
