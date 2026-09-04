#Requires -Version 7
<#
.SYNOPSIS
    Install dotfiles on Windows.

.DESCRIPTION
    Creates junctions, stubs, or copies to wire the dotfiles repo into the
    correct OS locations. Safe to re-run — existing targets are backed up
    before being replaced.

.PARAMETER Module
    One or more modules to install: neovim, vim, powershell, git, bash, tig, tmux, zellij, psmux, herdr, yazi, curl, claude, codex, pi, ai-agents, serena, context7, fastmail, langservers, biceptools, lazygit, windowsterminal, bat, vscode, winget, all.
    'ai-agents' is a composite that runs claude, codex, and pi in sequence; 'all' uses it
    instead of listing the three individually. claude, codex, and pi remain independently
    invocable on their own.
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

# This script targets Windows (see root CLAUDE.md); $env:USERPROFILE is normally set by the
# OS. But its -DryRun path is also exercised by cross-platform Pester tests in CI, and pwsh on
# non-Windows never populates $env:USERPROFILE, so every Join-Path against it below would throw
# on a null path. $HOME is PowerShell's own cross-platform automatic variable — fall back to it.
if (-not $env:USERPROFILE) { $env:USERPROFILE = $HOME }

# Expand 'all'
if ($Module -contains 'all') {
    # 'herdr' MUST come after 'claude' and 'codex': it runs `herdr integration install <agent>`,
    # which writes a hook registration into each agent's settings. claude's registration lands in
    # ~/.claude/settings.json — a file the claude module SYMLINKS to the repo. If herdr ran first,
    # that write would create a real settings.json, then the claude module's symlink would back it
    # up and replace it, silently dropping the herdr block. Running herdr last means it writes
    # through the already-established symlink into the repo file, so the block survives.
    #
    # 'langservers' comes after 'winget': it installs npm packages through Volta, which is part of
    # the curated winget set (Volta.Volta in winget/packages.json), so the order encodes the
    # dependency direction. Note the winget module only PRINTS the bootstrap command — it installs
    # nothing — so on a bare machine Volta is absent until winget/packages.ps1 has actually been
    # run; until then langservers warns and skips, and a re-run afterwards picks it up.
    #
    # 'biceptools' carries the same two-run caveat as 'langservers', against the .NET SDK instead
    # of Volta (both are part of the curated winget set): it must come after 'winget' and before
    # 'herdr' (below), which must stay last.
    #
    # 'ai-agents' replaces individually listing 'claude', 'codex', 'pi': it is the composite
    # module that runs all three in sequence (see Install-AiAgents). Listing both here would run
    # each runtime twice, since $Module is only deduplicated by name, not by the runtimes a
    # composite entry fans out to.
    $Module = @('neovim', 'vim', 'powershell', 'git', 'bash', 'tig', 'tmux', 'zellij', 'psmux', 'yazi', 'curl', 'ai-agents', 'serena', 'context7', 'fastmail', 'lazygit', 'windowsterminal', 'bat', 'vscode', 'winget', 'langservers', 'biceptools', 'herdr')
}
# @() wrapper: `Select-Object -Unique` over an empty array yields $null (and a
# single value yields a scalar), so without it the `$Module.Count` guard below
# throws under StrictMode when no -Module is passed.
$Module = @($Module | Select-Object -Unique)

# ── Output helpers ────────────────────────────────────────────────────────────

function Write-Info    ($Msg) { Write-Host "[INFO]  $Msg" -ForegroundColor Cyan    }
function Write-Ok      ($Msg) { Write-Host "[OK]    $Msg" -ForegroundColor Green   }
function Write-Warn    ($Msg) { Write-Host "[WARN]  $Msg" -ForegroundColor Yellow  }
function Write-Fail    ($Msg) { Write-Host "[ERROR] $Msg" -ForegroundColor Red     }

# ── Core helpers ──────────────────────────────────────────────────────────────

# Returns the backup path it moved $Path to, so a caller that goes on to attempt something
# risky (e.g. New-FileSymlink's New-Item) can restore the original on failure. Returns $null
# when there was nothing to back up, the link was a dangling reparse point (removed, no content
# to restore), or -DryRun (nothing was actually moved).
function Backup-Existing ([string]$Path) {
    # Test-Path resolves reparse points, so a symlink/junction whose target no longer exists
    # (e.g. after the dotfiles repo is moved to another drive) reads as "not present" — yet the
    # link entry still occupies the name and makes a later New-Item throw "already exists". Probe
    # with Get-Item -Force, which returns the reparse point WITHOUT following it, so re-running
    # setup.ps1 clears a stale/dangling link and self-heals a moved repo.
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $null }
    $ts     = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backup = "${Path}.bak.${ts}"
    # A dangling link has no content to preserve — remove it; otherwise rename to a timestamped .bak.
    if (-not $DryRun) {
        $isReparse = $item.Attributes -band [IO.FileAttributes]::ReparsePoint
        if ($isReparse -and -not (Test-Path -LiteralPath $Path)) {
            Remove-Item -LiteralPath $Path -Force
            Write-Warn "Removed dangling link:  $Path"
            return $null
        }
        Move-Item -LiteralPath $Path -Destination $backup
    }
    Write-Warn "Backed up:  $Path"
    Write-Warn "        ->  $backup"
    if ($DryRun) { return $null }
    return $backup
}

# Resolve a link's stored target for comparisons. Relative targets are relative to the
# link's parent, not the setup process CWD. A malformed target fails closed so callers
# preserve the existing entry rather than treating it as repository-managed.
function Resolve-LinkTargetPath ([string]$Link, [string]$Target) {
    if ([string]::IsNullOrWhiteSpace($Target)) { return $null }
    try {
        $candidate = if ([IO.Path]::IsPathRooted($Target)) {
            $Target
        } else {
            Join-Path (Split-Path -Parent $Link) $Target
        }
        return [IO.Path]::GetFullPath($candidate)
    } catch {
        return $null
    }
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
    # Get-Item is deliberate: Test-Path follows links and misses dangling managed entries.
    $existing = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $curTarget = if ($existing.LinkTarget) { $existing.LinkTarget } else { @($existing.Target)[0] }
            if ($curTarget) {
                $a = Resolve-LinkTargetPath -Link $Link -Target $curTarget
                $b = Resolve-LinkTargetPath -Link $Link -Target $Target
                if ($a -and $b -and [string]::Equals($a.TrimEnd('\'), $b.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
                    Write-Ok "Junction:   $Link (already current)"
                    return
                }
            }
        }
    }

    if ($DryRun) { Write-Info "[DRY RUN] junction $Link -> $Target"; return }

    $null = Backup-Existing $Link
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    Write-Ok "Junction:   $Link"
    Write-Ok "         -> $Target"
}

# File symlink — the live file points at the repo file, so edits flow both ways and there is
# no drift. Needs Developer Mode (or elevation) on Windows for non-elevated creation; junctions
# can't link files, only directories. With -Backup there is nothing to capture (linked), so skip.
# Replace only an installer-managed whole-directory link. Real directories, files, external links,
# and malformed links are user-owned/unknown and must remain untouched. Historical roots are
# compared lexically so dangling links remain safely repairable after a source move.
function New-ManagedDirectoryJunction ([string]$Link, [string]$Target, [string[]]$HistoricalTargets) {
    if ($Backup) { Write-Info "Skipped (linked, no drift):  $Link"; return }
    if (-not (Test-Path $Target -PathType Container)) {
        Write-Fail "Source directory not found: $Target"; return
    }

    $existing = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if (-not ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            Write-Warn "Preserved unmanaged directory: $Link"
            return
        }
        $curTarget = if ($existing.LinkTarget) { $existing.LinkTarget } else { @($existing.Target)[0] }
        $resolvedCurrent = Resolve-LinkTargetPath -Link $Link -Target $curTarget
        $managed = $false
        foreach ($candidate in @($Target) + @($HistoricalTargets)) {
            $resolvedCandidate = Resolve-LinkTargetPath -Link $Link -Target $candidate
            if ($resolvedCurrent -and $resolvedCandidate -and
                [string]::Equals($resolvedCurrent.TrimEnd('\', '/'), $resolvedCandidate.TrimEnd('\', '/'), [StringComparison]::OrdinalIgnoreCase)) {
                $managed = $true
                if ([string]::Equals($resolvedCurrent.TrimEnd('\', '/'), $resolvedCandidate.TrimEnd('\', '/'), [StringComparison]::OrdinalIgnoreCase) -and
                    [string]::Equals($resolvedCandidate.TrimEnd('\', '/'), (Resolve-LinkTargetPath -Link $Link -Target $Target).TrimEnd('\', '/'), [StringComparison]::OrdinalIgnoreCase)) {
                    Write-Ok "Junction:   $Link (already current)"
                    return
                }
                break
            }
        }
        if (-not $managed) {
            if ($resolvedCurrent -and -not (Test-Path -LiteralPath $resolvedCurrent)) {
                Write-Warn "Preserved unmanaged directory link (target missing): $Link"
            } else {
                Write-Warn "Preserved unmanaged directory link: $Link"
            }
            return
        }
    }

    if ($DryRun) { Write-Info "[DRY RUN] junction $Link -> $Target"; return }
    if ($existing) { Remove-Item -LiteralPath $Link -Force }
    $dir = Split-Path $Link
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    Write-Ok "Junction:   $Link"
    Write-Ok "         -> $Target"
}

function New-FileSymlink ([string]$Link, [string]$Target) {
    if ($Backup) { Write-Info "Skipped (linked, no drift):  $Link"; return }
    if (-not (Test-Path $Target -PathType Leaf)) {
        Write-Fail "Source file not found: $Target"; return
    }

    # Idempotent: leave an existing symlink that already points at $Target.
    # Get-Item is deliberate: Test-Path follows links and misses dangling entries.
    $existing = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $curTarget = if ($existing.LinkTarget) { $existing.LinkTarget } else { @($existing.Target)[0] }
            if ($curTarget) {
                $a = Resolve-LinkTargetPath -Link $Link -Target $curTarget
                $b = Resolve-LinkTargetPath -Link $Link -Target $Target
                if ($a -and $b -and [string]::Equals($a, $b, [StringComparison]::OrdinalIgnoreCase)) {
                    Write-Ok "Symlink:    $Link (already current)"
                    return
                }
            }
        }
    }

    if ($DryRun) { Write-Info "[DRY RUN] symlink $Link -> $Target"; return }

    $dir = Split-Path $Link
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $backupPath = Backup-Existing $Link
    try {
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target -ErrorAction Stop | Out-Null
    } catch {
        Write-Fail "Symlink failed for $Link ($($_.Exception.Message)). Enable Developer Mode (Settings > For developers) or run elevated."
        # Backup-Existing already moved the live file out of the way before this attempt — if we
        # don't move it back, a failed symlink (no Developer Mode) leaves the user's real config
        # renamed to a .bak file with nothing in its place.
        if ($backupPath -and (Test-Path -LiteralPath $backupPath)) {
            Move-Item -LiteralPath $backupPath -Destination $Link -Force
            Write-Warn "Restored original:  $Link"
        }
        return
    }
    Write-Ok "Symlink:    $Link"
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
        if ($DryRun) {
            Write-Info "[DRY RUN] would create: $dir"
        } else {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Info "Created:    $dir"
        }
    }
    if ($DryRun) { Write-Info "[DRY RUN] copy $Source -> $Dest"; return }

    $null = Backup-Existing $Dest
    Copy-Item -Path $Source -Destination $Dest -Force
    Write-Ok "Copied:     $Dest"
    Write-Warn "(Re-run setup.ps1 after editing this file in the repo)"
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

    $null = Backup-Existing $StubPath
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

    # ~/.git_work_hooks — work-only policy hooks, referenced by [hook "work-policy"]
    # in gitconfig-work. Deliberately NOT nested under ~/.git_templates: templatedir
    # copies that directory's contents into every new repo's .git/, which would put
    # the work hooks inside personal repos too.
    $params = @{
        Link = Join-Path $env:USERPROFILE '.git_work_hooks'
        Target = Join-Path $Dotfiles 'git\work-hooks'
    }
    New-Junction @params

    Test-GitHookSupport
}

# Config-based hooks ([hook "work-policy"] in gitconfig-work) need Git >= 2.54.
# Older git ignores the stanza SILENTLY — no error, the hook simply never runs — so
# warn at install time rather than let a policy hook quietly enforce nothing.
function Test-GitHookSupport {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warn 'git not on PATH — cannot verify config-based hook support (needs >= 2.54).'
        return
    }

    [string] $raw = (& git --version) -replace '^git version\s*', ''
    if ($raw -notmatch '^(\d+)\.(\d+)') {
        Write-Warn "Could not parse git version '$raw' — config-based hooks need >= 2.54."
        return
    }

    [version] $found = [version]::new([int]$Matches[1], [int]$Matches[2])
    if ($found -lt [version]'2.54') {
        Write-Warn "git $raw is older than 2.54 — the work-policy hook in gitconfig-work is IGNORED SILENTLY."
        Write-Warn '  Upgrade git, or move the check into git/templates/hooks/pre-commit to enforce it on this machine.'
    } else {
        Write-Ok "git $raw supports config-based hooks (>= 2.54)."
    }
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

    # Stub into the PS7 + VSCode profile locations — BOTH under Documents\PowerShell\.
    # VSCode's PowerShell extension is configured for pwsh 7 (powershell.powerShellDefaultVersion
    # = "pwsh"), so its profile is Microsoft.VSCode_profile.ps1 there, not under WindowsPowerShell.
    # The shared profile is pwsh-7-only (#Requires -Version 7), so Windows PowerShell 5.1 is
    # intentionally NOT targeted — see the orphaned-stub warning below and powershell/README.md.
    # Resolves the repo path via $env:DOTFILES at load time — no hardcoded path.
    $stubContent = @'
# Auto-generated by setup.ps1 — do not edit directly.
# Re-run setup.ps1 -Module powershell if the dotfiles path changes.
. (Join-Path $env:DOTFILES 'powershell\Microsoft.PowerShell_profile.ps1')
'@

    $profileTargets = @(
        (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'), # PS7
        (Join-Path $docs 'PowerShell\Microsoft.VSCode_profile.ps1')      # VSCode (runs pwsh 7)
    )
    foreach ($target in $profileTargets) {
        $dir = Split-Path $target
        if (-not (Test-Path $dir)) {
            if (-not $DryRun) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Write-Info "Created:    $dir"
        }
        if ($DryRun) { Write-Info "[DRY RUN] stub $target -> `$env:DOTFILES\powershell\..."; continue }
        $null = Backup-Existing $target
        Set-Content -Path $target -Value $stubContent -Encoding UTF8
        Write-Ok "Stub:       $target"
        Write-Ok "         -> `$env:DOTFILES\powershell\Microsoft.PowerShell_profile.ps1"
    }

    # Warn about orphaned Windows PowerShell 5.1 stubs left by older installer runs. A PS5 stub
    # dot-sourcing the pwsh-7-only shared profile fails on load (#Requires -Version 7). We do NOT
    # auto-delete — the WindowsPowerShell\ dir holds real user content — only flag stubs this
    # installer generated (identified by the auto-generated header), with a manual removal command.
    if (-not $DryRun) {
        $ps5Stubs = @(
            (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
            (Join-Path $docs 'WindowsPowerShell\Microsoft.VSCode_profile.ps1')
        )
        foreach ($stub in $ps5Stubs) {
            if ((Test-Path $stub -PathType Leaf) -and
                ((Get-Content $stub -Raw -ErrorAction SilentlyContinue) -match 'Auto-generated by setup\.ps1')) {
                Write-Warn "Orphaned PS5 stub (shared profile needs pwsh 7): $stub"
                Write-Warn "        remove with:  Remove-Item '$stub'"
            }
        }
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
    # -Backup is a reverse-sync (live -> repo) that never touches the live side, and
    # New-Junction itself skips under -Backup — but this mkdir ran unconditionally ahead of
    # that check, so a -Backup run could still mutate the filesystem. Guard it here too.
    if (-not (Test-Path $zellijParent) -and -not $Backup) {
        if ($DryRun) {
            Write-Info "[DRY RUN] would create: $zellijParent"
        } else {
            New-Item -ItemType Directory -Path $zellijParent -Force | Out-Null
            Write-Info "Created:    $zellijParent"
        }
    }
    $params = @{
        Link = $zellijConfig
        Target = Join-Path $Dotfiles 'zellij'
    }
    New-Junction @params
}

function Install-Psmux {
    Write-Host ''
    Write-Info '=== psmux (native-Windows tmux) ==='
    # psmux auto-loads ~/.psmux.conf (verified: it wins over ~/.tmux.conf). Symlink so edits
    # flow both ways with the repo; needs Developer Mode (see New-FileSymlink).
    New-FileSymlink -Link (Join-Path $env:USERPROFILE '.psmux.conf') -Target (Join-Path $Dotfiles 'psmux\psmux.conf')

    if (-not (Get-Command -Name psmux -ErrorAction Ignore)) {
        Write-Warn 'psmux not found. Install with: winget install marlocarlo.psmux'
    } else {
        Write-Ok 'psmux is installed.'
    }

    # Plugins (resurrect/continuum) are vendored + SHA-pinned in the repo (psmux/plugins/ — see its
    # README) and COPIED into ~/.psmux/plugins/. psmux.conf `source-file`s each plugin.conf directly
    # (no PPM, no network, no namespace-hijack surface). Copied, NOT junctioned: psmux-continuum
    # rewrites its own scripts/ dir at load, so a junction would mutate the committed repo.
    # -Backup is a reverse-sync (live -> repo); these are forward (repo -> live) copies with
    # nothing to reverse-sync, so skip the whole loop rather than forward-copying during a
    # -Backup run.
    if ($Backup) {
        Write-Info 'Skipped (vendored copy, no drift):  ~/.psmux/plugins'
        return
    }
    $pluginsSrc = Join-Path $Dotfiles 'psmux\plugins'
    $pluginsDst = Join-Path $env:USERPROFILE '.psmux\plugins'
    if (-not (Test-Path $pluginsDst)) {
        if ($DryRun) {
            Write-Info "[DRY RUN] would create: $pluginsDst"
        } else {
            New-Item -ItemType Directory -Path $pluginsDst -Force | Out-Null
            Write-Info "Created:    $pluginsDst"
        }
    }
    $plugins = Get-ChildItem -Path $pluginsSrc -Directory -ErrorAction SilentlyContinue
    if ($plugins) {
        foreach ($plugin in $plugins) {
            $dest = Join-Path $pluginsDst $plugin.Name
            if ($DryRun) { Write-Info "[DRY RUN] copy plugin $($plugin.Name) -> $dest"; continue }
            Copy-Item -Path $plugin.FullName -Destination $pluginsDst -Recurse -Force
            Write-Ok "Plugin:     $dest (vendored, pinned)"
        }
    } else {
        Write-Info 'No vendored plugins found (psmux/plugins/ is empty).'
    }
}

function Install-Herdr {
    Write-Host ''
    Write-Info '=== Herdr (terminal workspace manager for AI agents) ==='
    # Herdr reads ~/.config/herdr/config.toml on every platform including Windows
    # (verified from the server log's own path output) — it does not use %APPDATA%.
    # Only config.toml is linked, NOT the whole directory: herdr keeps its runtime
    # state (session.json, herdr.sock, *.log) alongside it, which must stay untracked.
    $herdrConfig = Join-Path $env:USERPROFILE '.config\herdr'
    # -Backup is a reverse-sync (live -> repo) and must never mutate the live side;
    # New-FileSymlink skips under -Backup, so guard the mkdir the same way (mirrors Install-Zellij).
    if (-not (Test-Path $herdrConfig) -and -not $Backup) {
        if ($DryRun) {
            Write-Info "[DRY RUN] would create: $herdrConfig"
        } else {
            New-Item -ItemType Directory -Path $herdrConfig -Force | Out-Null
            Write-Info "Created:    $herdrConfig"
        }
    }
    $params = @{
        Link = Join-Path $herdrConfig 'config.toml'
        Target = Join-Path $Dotfiles 'herdr\config.toml'
    }
    New-FileSymlink @params

    if (-not (Get-Command -Name herdr -ErrorAction Ignore)) {
        Write-Warn 'herdr not found on PATH. Install from https://herdr.dev'
    } else {
        Write-Ok 'herdr is installed.'
        Write-Info 'Validate with: herdr config check   Apply live with: herdr server reload-config'

        # Wire herdr's agent-state hooks into the installed AI agents so herdr can track each
        # pane's live agent session. `herdr integration install <agent>` is idempotent (a re-run
        # is a verified no-op) and writes agent-side files herdr manages itself — the hook script
        # (~/.claude/hooks, ~/.codex) plus its registration in that agent's settings — so nothing
        # is vendored here; setup regenerates it per machine with correct paths. Only agents
        # actually on PATH are wired. pi is omitted: `herdr integration install pi` reports "not
        # supported on Windows" (it is wired on Linux by setup.sh instead).
        foreach ($agent in @('claude', 'codex')) {
            if (-not (Get-Command -Name $agent -ErrorAction Ignore)) { continue }
            if ($Backup) { continue }  # reverse-sync must never mutate the live side
            if ($DryRun) {
                Write-Info "[DRY RUN] herdr integration install $agent"
                continue
            }
            herdr integration install $agent *>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Integration: $agent wired to herdr"
            } else {
                Write-Warn "herdr integration install $agent failed (exit $LASTEXITCODE)"
            }
        }
    }
}

function Install-Yazi {
    Write-Host ''
    Write-Info '=== Yazi ==='
    $yaziConfig = Join-Path $env:APPDATA 'yazi\config'
    $yaziParent = Join-Path $env:APPDATA 'yazi'
    # -Backup is a reverse-sync (live -> repo) that never touches the live side, and
    # New-Junction itself skips under -Backup — but this mkdir ran unconditionally ahead of
    # that check, so a -Backup run could still mutate the filesystem. Guard it here too.
    if (-not (Test-Path $yaziParent) -and -not $Backup) {
        if ($DryRun) {
            Write-Info "[DRY RUN] would create: $yaziParent"
        } else {
            New-Item -ItemType Directory -Path $yaziParent -Force | Out-Null
            Write-Info "Created:    $yaziParent"
        }
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
    $batCmd = Get-Command -Name bat -ErrorAction Ignore
    if (-not $batCmd) {
        Write-Warn 'bat not found. Install with: winget install sharkdp.bat'
        return
    }
    Write-Ok 'bat is installed.'

    # -Backup is a reverse live -> repo sync (see Copy-Dotfile); there is nothing here to
    # pull back into the repo (themes are fetched content, not tracked), so skip entirely.
    if ($Backup) {
        Write-Info 'Backup mode — skipping theme provisioning.'
        return
    }

    Install-BatCatppuccinTheme -BatCmd $batCmd
}

# bat doesn't ship the Catppuccin themes the PowerShell profile selects via $env:BAT_THEME
# ('Catppuccin Mocha' / 'Catppuccin Latte' — see Microsoft.PowerShell_profile.ps1) — without
# this, a fresh machine gets a "theme not found" warning from bat and falls back to its
# default. Downloads the two .tmTheme files from the official catppuccin/bat repo into bat's
# own theme directory when missing, then rebuilds bat's theme cache — but only when a theme
# was actually added, so a re-run with both themes already present costs nothing.
#
# Split out from Install-Bat (and takes $BatCmd as a param rather than re-resolving it) so a
# test can call the theme-dir-resolution/skip logic directly against a shimmed `bat` on PATH
# without needing a real bat install or network access.
function Install-BatCatppuccinTheme ([System.Management.Automation.CommandInfo]$BatCmd) {
    # bat's own convention: `bat --config-dir`/themes is where it looks for user themes.
    $configDir = (& $BatCmd --config-dir | Select-Object -First 1)
    if (-not $configDir) {
        Write-Warn 'Could not determine `bat --config-dir` — skipping Catppuccin theme provisioning.'
        return
    }
    $themesDir = Join-Path $configDir 'themes'

    # https://github.com/catppuccin/bat/tree/main/themes — raw file per flavor, %20 for the space.
    $themes = @(
        @{ Name = 'Catppuccin Mocha'; Url = 'https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme' }
        @{ Name = 'Catppuccin Latte'; Url = 'https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Latte.tmTheme' }
    )

    $added = $false
    $missing = $false
    foreach ($theme in $themes) {
        $dest = Join-Path $themesDir "$($theme.Name).tmTheme"
        if (Test-Path -LiteralPath $dest) {
            Write-Ok "Theme:      $dest (already present)"
            continue
        }
        $missing = $true
        if ($DryRun) {
            Write-Info "[DRY RUN] would download $($theme.Url) -> $dest"
            continue
        }
        if (-not (Test-Path $themesDir)) {
            New-Item -ItemType Directory -Path $themesDir -Force | Out-Null
            Write-Info "Created:    $themesDir"
        }
        # Fails open, like Install-Codex's installer download: a blocked/offline network must
        # not abort the rest of -Module all, just leave bat on its (warn-and-fall-back) default.
        try {
            Invoke-WebRequest -Uri $theme.Url -OutFile $dest -ErrorAction Stop
            Write-Ok "Downloaded: $dest"
            $added = $true
        } catch {
            Write-Warn "Could not download '$($theme.Name)' theme ($($_.Exception.Message))."
            Write-Warn "  bat will warn and fall back to its default theme until this succeeds — re-run this module, or download manually (see bat/README.md)."
        }
    }

    if ($DryRun) {
        if ($missing) { Write-Info '[DRY RUN] would run: bat cache --build' }
        return
    }
    if ($added) {
        & $BatCmd cache --build
        Write-Ok 'Rebuilt bat theme cache (bat cache --build).'
    }
}

function Get-ClaudeCli {
    $command = Get-Command -Name claude -ErrorAction Ignore
    if ($command) { return $command }

    # The native installer places the executable here, but a running PowerShell process may not
    # have received the PATH update made by the installer. Refresh this process before gating
    # configuration so a successful bootstrap is usable immediately.
    $nativeBin = Join-Path $HOME '.local\bin'
    $nativeExe = Join-Path $nativeBin 'claude.exe'
    if (Test-Path -LiteralPath $nativeExe -PathType Leaf) {
        $pathParts = @($env:PATH -split [IO.Path]::PathSeparator)
        if ($nativeBin -notin $pathParts) { $env:PATH = "$nativeBin$([IO.Path]::PathSeparator)$env:PATH" }
        return Get-Command -Name claude -ErrorAction SilentlyContinue
    }
    return $null
}

function Confirm-ClaudeCli {
    if (Get-ClaudeCli) {
        Write-Ok 'Claude Code CLI is already installed.'
        return $true
    }
    if ($DryRun) {
        Write-Info '[DRY RUN] would install Claude Code CLI via https://claude.ai/install.ps1'
        return $true
    }

    Write-Info 'Claude Code CLI not found — installing via the native installer...'
    try {
        # Supported Windows install path; deliberately do not use npm/Volta.
        $installer = Invoke-RestMethod -Uri 'https://claude.ai/install.ps1' -ErrorAction Stop
        if (-not $installer) { throw 'The native installer returned an empty response.' }
        Invoke-Expression $installer
    } catch {
        Write-Fail "Claude Code CLI bootstrap failed: $($_.Exception.Message)"
    }

    if (-not (Get-ClaudeCli)) {
        Write-Fail 'Claude setup stopped before configuration or projection because the CLI is unavailable.'
        Write-Info 'Install it manually with: irm https://claude.ai/install.ps1 | iex'
        Write-Info 'Then verify `claude` is on PATH and re-run: .\setup.ps1 -Module claude'
        return $false
    }
    Write-Ok 'Claude Code CLI installed.'
    return $true
}

function Install-Claude {
    Write-Host ''
    Write-Info '=== Claude Code ==='
    if ($Backup) {
        Write-Info 'Backup mode — skipping Claude installation and projection.'
        return
    }
    if (-not (Confirm-ClaudeCli)) { return }
    $claudeDir = Join-Path $env:USERPROFILE '.claude'
    # Symlink the tracked files into the repo so live == repo (no drift, no sync needed).
    # settings.json and CLAUDE.md self-mutate (Claude writes settings; /memory appends), so the
    # link lets those edits land straight in the repo. Needs Developer Mode (see New-FileSymlink).
    New-FileSymlink -Link (Join-Path $claudeDir 'settings.json') -Target (Join-Path $Dotfiles 'claude\settings.json')
    New-FileSymlink -Link (Join-Path $claudeDir 'CLAUDE.md') -Target (Join-Path $Dotfiles 'claude\CLAUDE.md')
    # Shared coding conventions. CLAUDE.md imports this via `@../ai-agents/AGENTS.md` (resolves
    # to ~/.claude/AGENTS.md). The codex module installs the same source to ~/.codex/AGENTS.md.
    New-FileSymlink -Link (Join-Path $claudeDir 'AGENTS.md') -Target (Join-Path $Dotfiles 'ai-agents\AGENTS.md')
    # Progressive-disclosure satellite files AGENTS.md links out to on demand (e.g. git worktrees,
    # project brain) — junctioned whole-dir like output-styles/agents so the links resolve live.
    New-Junction -Link (Join-Path $claudeDir 'AGENTS.d') -Target (Join-Path $Dotfiles 'ai-agents\AGENTS.d')
    New-FileSymlink -Link (Join-Path $claudeDir 'statusline-command.sh') -Target (Join-Path $Dotfiles 'claude\statusline-command.sh')
    # PreToolUse hook wired in settings.json; hard-blocks AI/Claude/Codex/Copilot/co-authored-by
    # references from landing in a commit, PR, or Azure Boards item (issue #219).
    New-FileSymlink -Link (Join-Path $claudeDir 'no-claude-session-trailer.sh') -Target (Join-Path $Dotfiles 'claude\no-claude-session-trailer.sh')
    # Shared wordlist the hook above reads as a sibling file at its own runtime path. Also
    # projected to Codex (copied) and Pi (symlinked) — see those modules below.
    New-FileSymlink -Link (Join-Path $claudeDir 'banned-ai-terms.txt') -Target (Join-Path $Dotfiles 'ai-agents\_shared\banned-ai-terms.txt')
    # pwsh-native hooks wired in settings.json: PreToolUse guardrails (destructive git, PowerShell
    # mis-sent to the Bash tool) and a PostToolUse PSScriptAnalyzer lint-on-edit pass.
    New-FileSymlink -Link (Join-Path $claudeDir 'block-destructive-vcs.ps1') -Target (Join-Path $Dotfiles 'claude\block-destructive-vcs.ps1')
    New-FileSymlink -Link (Join-Path $claudeDir 'block-pwsh-in-bash.ps1') -Target (Join-Path $Dotfiles 'claude\block-pwsh-in-bash.ps1')
    New-FileSymlink -Link (Join-Path $claudeDir 'lint-powershell.ps1') -Target (Join-Path $Dotfiles 'claude\lint-powershell.ps1')
    # PreToolUse ask-to-confirm on edits to legacy/do-not-touch dotfiles; PostToolUse hardcoded-secret warn.
    New-FileSymlink -Link (Join-Path $claudeDir 'warn-legacy-files.ps1') -Target (Join-Path $Dotfiles 'claude\warn-legacy-files.ps1')
    New-FileSymlink -Link (Join-Path $claudeDir 'warn-hardcoded-secrets.ps1') -Target (Join-Path $Dotfiles 'claude\warn-hardcoded-secrets.ps1')
    # UserPromptSubmit advisory + PreToolUse ask on reasoning-extraction phrasing (Fable fallback risk).
    New-FileSymlink -Link (Join-Path $claudeDir 'warn-reasoning-extraction.ps1') -Target (Join-Path $Dotfiles 'claude\warn-reasoning-extraction.ps1')
    # SessionStart hook: inject a pending .claude/handoff.md (from the handoff skill) into a fresh session.
    New-FileSymlink -Link (Join-Path $claudeDir 'inject-handoff.ps1') -Target (Join-Path $Dotfiles 'claude\inject-handoff.ps1')
    # SessionStart hook: nudge when the current project's auto-memory store is overdue for review.
    New-FileSymlink -Link (Join-Path $claudeDir 'memory-review-nudge.ps1') -Target (Join-Path $Dotfiles 'claude\memory-review-nudge.ps1')

    # Skills — project portable and Claude-native resources into ~/.claude/skills/.
    # Native names win collisions so each destination receives exactly one link.
    $skillsDst = Join-Path $claudeDir 'skills'
    $portableSkills = @(Get-ChildItem -Path (Join-Path $Dotfiles 'ai-agents\skills') -Directory -ErrorAction SilentlyContinue)
    $nativeSkills = @(Get-ChildItem -Path (Join-Path $Dotfiles 'claude\skills') -Directory -ErrorAction SilentlyContinue)
    $nativeNames = @($nativeSkills.ForEach('Name'))
    $portableSkills = @($portableSkills | Where-Object { $_.Name -notin $nativeNames })
    $skills = @($portableSkills) + @($nativeSkills)
    # Keep repository-relative compatibility roots indefinitely; missing historical roots are
    # intentionally not recreated; they are only used to recognize old managed links. Scoped to
    # roots the Claude installer itself (current or historical) has ever written into — never
    # a root only Pi's or Codex's installer wrote (see issue #71).
    $managedSkillRoots = @(
        (Join-Path $Dotfiles 'ai-agents\skills'),
        (Join-Path $Dotfiles 'claude\skills'),
        (Join-Path $Dotfiles 'ai-agents\shared\skills'),
        (Join-Path $Dotfiles 'ai-agents\claude\skills')
    )
    if (-not (Test-Path $skillsDst)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null }
        Write-Info "Created:    $skillsDst"
    }
    Remove-ObsoleteManagedSkillLinks -SkillsDst $skillsDst -DesiredNames @($skills | ForEach-Object Name) -ManagedRoots $managedSkillRoots -Runtime 'Claude'
    if ($skills) {
        foreach ($skill in $skills) {
            $link = Join-Path $skillsDst $skill.Name
            $existing = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
            if ($existing) {
                if (-not ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                    Write-Warn "Preserved unmanaged Claude skill: $link"
                    continue
                }
                $existingTarget = if ($existing.LinkTarget) { $existing.LinkTarget } else { @($existing.Target)[0] }
                $fullExistingTarget = Resolve-LinkTargetPath -Link $link -Target $existingTarget
                $isManaged = Test-ManagedSkillLink -Link $link -FullTarget $fullExistingTarget -ManagedRoots $managedSkillRoots
                if (-not $isManaged) {
                    if ($fullExistingTarget -and -not (Test-Path -LiteralPath $fullExistingTarget)) {
                        Write-Warn "Preserved unmanaged Claude skill link (target missing): $link"
                    } else {
                        Write-Warn "Preserved unmanaged Claude skill link: $link"
                    }
                    continue
                }
            }
            New-Junction -Link $link -Target $skill.FullName
        }
    } else {
        Write-Info 'No skills to install (ai-agents/skills and claude/skills are empty).'
    }

    # Agents — junction the whole dir into ~/.claude/agents/ (unlike skills, which junction
    # per-subdir). Agent definitions are flat .md files in one dir nothing else writes to, so a
    # whole-dir junction preserves the no-drift philosophy and lets agents created via /agents
    # land straight in the repo. Bodies are self-contained — they can't @import AGENTS.md.
    $agentsSrc = Join-Path $Dotfiles 'ai-agents\agents'
    $historicalAgentsSrc = Join-Path $Dotfiles 'ai-agents\shared\agents'
    # The original agents source, before the ai-agents-module migration introduced
    # ai-agents\shared\agents (later itself migrated to ai-agents\agents). Kept as a historical
    # root indefinitely so a machine whose ~/.claude/agents link predates that migration stays
    # repairable instead of being permanently misclassified as an unrecognized/dangling link.
    $originalAgentsSrc = Join-Path $Dotfiles 'claude\agents'
    if (Test-Path $agentsSrc) {
        New-ManagedDirectoryJunction -Link (Join-Path $claudeDir 'agents') -Target $agentsSrc -HistoricalTargets @($historicalAgentsSrc, $originalAgentsSrc)
    } else {
        Write-Info 'No agents to install (ai-agents/agents/ is missing).'
    }

    # Output styles — whole-dir junction like agents: flat .md files in a dir nothing else
    # writes to. The active style is pinned by "outputStyle" in settings.json.
    $stylesSrc = Join-Path $Dotfiles 'claude\output-styles'
    if (Test-Path $stylesSrc) {
        New-Junction -Link (Join-Path $claudeDir 'output-styles') -Target $stylesSrc
    } else {
        Write-Info 'No output styles to install (claude/output-styles/ is missing).'
    }
}

function Install-Pi {
    Write-Host ''
    Write-Info '=== Pi ==='

    if ($Backup) {
        Write-Info 'Backup mode — skipping Pi installation and projection.'
        return
    }

    # Do not touch Pi state until the executable is available. This makes a failed bootstrap
    # safe to retry and prevents a partial configuration from looking like a valid install.
    if (Get-Command -Name pi -ErrorAction Ignore) {
        Write-Ok 'pi is already installed.'
    } elseif ($DryRun) {
        Write-Info '[DRY RUN] would install Pi via npm (@mariozechner/pi-coding-agent)'
    } else {
        if (-not (Get-Command -Name npm -ErrorAction Ignore)) {
            Write-Fail 'npm not found — Pi setup stopped before changing Pi configuration.'
            return
        }
        Write-Info 'Installing Pi via npm...'
        & npm install --global '@mariozechner/pi-coding-agent'
        if ($LASTEXITCODE -ne 0 -or -not (Get-Command -Name pi -ErrorAction Ignore)) {
            Write-Fail 'Pi installation failed — no Pi configuration or resources were changed.'
            return
        }
        Write-Ok 'Pi installed.'
    }

    $piDir = Join-Path $env:USERPROFILE '.pi\agent'
    $piSettings = Get-Content (Join-Path $Dotfiles 'pi\settings.json') -Raw | ConvertFrom-Json
    # Install packages before projecting tracked configuration/resources. If a pinned package
    # fails, the return below leaves the existing Pi configuration and resources untouched.
    foreach ($package in @($piSettings.packages)) {
        if ($DryRun) {
            Write-Info "[DRY RUN] pi install $package"
            continue
        }
        & pi install $package
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Pi package install failed for $package — repository resources were not projected."
            return
        }
    }
    # Validate or migrate skills before projecting any tracked Pi configuration/resources.
    # Skills need two source areas, so project children rather than linking the whole directory.
    # Remove the former whole-directory junction only when it is exactly repository-managed.
    $skillsDst = Join-Path $piDir 'skills'
    $oldSkillsTarget = Join-Path $Dotfiles 'pi\skills'
    $skillsItem = Get-Item -LiteralPath $skillsDst -Force -ErrorAction SilentlyContinue
    if ($skillsItem -and ($skillsItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        $target = if ($skillsItem.LinkTarget) { $skillsItem.LinkTarget } else { @($skillsItem.Target)[0] }
        $resolvedTarget = Resolve-LinkTargetPath -Link $skillsDst -Target $target
        $resolvedOldTarget = Resolve-LinkTargetPath -Link $skillsDst -Target $oldSkillsTarget
        if ($resolvedTarget -and $resolvedOldTarget -and [string]::Equals($resolvedTarget.TrimEnd('\'), $resolvedOldTarget.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
            if ($DryRun) { Write-Info "[DRY RUN] remove managed Pi skills junction: $skillsDst" }
            else { Remove-Item -LiteralPath $skillsDst -Force; Write-Warn "Removed managed Pi skills junction: $skillsDst" }
            $skillsItem = $null
        } else {
            Write-Fail "Pi skills junction is unmanaged; preserving it: $skillsDst"
            return
        }
    }
    if ($skillsItem -and -not (Test-Path $skillsDst -PathType Container)) {
        Write-Fail "Pi skills destination is unmanaged and is not a directory: $skillsDst"
        return
    }
    if (-not $skillsItem -and -not (Test-Path $skillsDst)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null }
        Write-Info "Created:    $skillsDst"
    }

    Copy-Dotfile -Dest (Join-Path $piDir 'settings.json') -Source (Join-Path $Dotfiles 'pi\settings.json')
    foreach ($resource in @('extensions', 'prompts', 'themes')) {
        New-Junction -Link (Join-Path $piDir $resource) -Target (Join-Path $Dotfiles "pi\$resource")
    }
    # Shared wordlist ai-reference-guard.ts reads as a sibling of the junctioned extensions/
    # dir, not inside it — extensions/ is a whole-directory JUNCTION straight into this
    # repo's pi/extensions/, so a symlink placed inside it would land as a real filesystem
    # entry inside the tracked repo directory, showing up as untracked on every
    # `setup.ps1 -Module pi` run. Symlinked (not junctioned like the whole-dir resources
    # above) since it's a single file living outside pi/extensions/ in the repo — matches
    # the claude module's per-file New-FileSymlink pattern for the same wordlist (issue #219).
    New-FileSymlink -Link (Join-Path $piDir 'banned-ai-terms.txt') -Target (Join-Path $Dotfiles 'ai-agents\_shared\banned-ai-terms.txt')

    $nativeSkills = @(Get-ChildItem -Path $oldSkillsTarget -Directory -ErrorAction SilentlyContinue)
    $nativeNames = @($nativeSkills.ForEach('Name'))
    $portableSkills = @(Get-ChildItem -Path (Join-Path $Dotfiles 'ai-agents\skills') -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $nativeNames })
    $skills = @($portableSkills) + @($nativeSkills)
    # Scoped to roots the Pi installer itself (current or historical) has ever written into —
    # Pi never wrote into any Claude- or Codex-only historical root (see issue #71).
    $managedSkillRoots = @(
        (Join-Path $Dotfiles 'ai-agents\skills'),
        (Join-Path $Dotfiles 'pi\skills'),
        (Join-Path $Dotfiles 'ai-agents\shared\skills')
    )
    $desiredSkillNames = @($skills | ForEach-Object Name)
    Remove-ObsoleteManagedSkillLinks -SkillsDst $skillsDst -DesiredNames $desiredSkillNames -ManagedRoots $managedSkillRoots -Runtime 'Pi'
    foreach ($skill in $skills) {
        $link = Join-Path $skillsDst $skill.Name
        $existing = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
        if ($existing) {
            if (-not ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                Write-Warn "Preserved unmanaged Pi skill: $link"
                continue
            }
            $existingTarget = if ($existing.LinkTarget) { $existing.LinkTarget } else { @($existing.Target)[0] }
            $fullExistingTarget = Resolve-LinkTargetPath -Link $link -Target $existingTarget
            $isManaged = Test-ManagedSkillLink -Link $link -FullTarget $fullExistingTarget -ManagedRoots $managedSkillRoots
            if (-not $isManaged) {
                if ($fullExistingTarget -and -not (Test-Path -LiteralPath $fullExistingTarget)) {
                    Write-Warn "Preserved unmanaged Pi skill link (target missing): $link"
                } else {
                    Write-Warn "Preserved unmanaged Pi skill link: $link"
                }
                continue
            }
        }
        New-Junction -Link $link -Target $skill.FullName
    }
}

# A link is repository-managed only when its resolved target is beneath one of the caller's
# current or historical skill roots. Each root is resolved relative to $Link (not $Dotfiles)
# so relative link targets stored on disk still match.
function Test-ManagedSkillLink ([string]$Link, [string]$FullTarget, [string[]]$ManagedRoots) {
    if (-not $FullTarget) { return $false }
    foreach ($root in $ManagedRoots) {
        $fullRoot = Resolve-LinkTargetPath -Link $Link -Target $root
        if ($fullRoot -and
            $FullTarget.StartsWith($fullRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

# Remove obsolete links only when their resolved target is beneath a known current or
# historical repository skill root. Unmanaged links, malformed links, and real entries stay.
function Remove-ObsoleteManagedSkillLinks ([string]$SkillsDst, [string[]]$DesiredNames, [string[]]$ManagedRoots, [string]$Runtime) {
    if ($Backup -or -not (Test-Path $SkillsDst -PathType Container)) { return }

    foreach ($item in @(Get-ChildItem -LiteralPath $SkillsDst -Force -ErrorAction SilentlyContinue)) {
        if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
        $target = if ($item.LinkTarget) { $item.LinkTarget } else { @($item.Target)[0] }
        if (-not $target) { continue }
        $fullTarget = Resolve-LinkTargetPath -Link $item.FullName -Target $target
        $isManaged = Test-ManagedSkillLink -Link $item.FullName -FullTarget $fullTarget -ManagedRoots $ManagedRoots
        if ($isManaged -and $item.Name -notin $DesiredNames) {
            if ($DryRun) {
                Write-Info "[DRY RUN] remove obsolete $Runtime skill junction: $($item.FullName)"
            } else {
                Remove-Item -LiteralPath $item.FullName -Force
                Write-Warn "Removed obsolete $Runtime skill junction: $($item.FullName)"
            }
        }
    }
}

function Confirm-CodexCli {
    if (Get-Command -Name codex -ErrorAction Ignore) {
        Write-Ok 'codex is already installed.'
        return $true
    }
    if ($DryRun) {
        Write-Info '[DRY RUN] would install Codex CLI via native installer (https://chatgpt.com/codex/install.ps1)'
        return $true
    }

    Write-Info 'Installing Codex CLI (native installer)...'
    $installer = Join-Path $env:TEMP 'codex-install.ps1'
    try {
        Invoke-RestMethod -Uri 'https://chatgpt.com/codex/install.ps1' -OutFile $installer
        & $installer
    } catch {
        Write-Fail "Codex CLI install failed: $($_.Exception.Message)"
    } finally {
        Remove-Item -Path $installer -Force -ErrorAction Ignore
    }

    if (-not (Get-Command -Name codex -ErrorAction Ignore)) {
        Write-Fail 'Codex setup stopped before configuration or projection because the executable is unavailable.'
        Write-Info 'Install it manually with: irm https://chatgpt.com/codex/install.ps1 | iex'
        Write-Info 'Then verify `codex` is on PATH and re-run: .\setup.ps1 -Module codex'
        return $false
    }
    Write-Ok 'codex installed.'
    return $true
}

function Resolve-CodexGuardrailBash {
    # Codex CLI executes command hooks with no shell field, so on Windows a bare `bash` in the
    # tracked hooks.json fragment resolves through normal PATH search — on a machine with WSL
    # installed (the common case) that is C:\Windows\System32\bash.exe, the WSL launcher, where
    # the guardrail script does not exist. Resolve a real Git-for-Windows bash.exe instead.
    $candidates = [System.Collections.Generic.List[string]]::new()

    $gitCmd = Get-Command -Name git -ErrorAction Ignore
    if ($gitCmd) {
        $gitBinDir = Split-Path $gitCmd.Source
        # cmd\git.exe layout -> ..\..\bin\bash.exe; bin\git.exe layout -> ..\bin\bash.exe.
        $candidates.Add((Join-Path $gitBinDir '..\..\bin\bash.exe'))
        $candidates.Add((Join-Path $gitBinDir '..\bin\bash.exe'))
    }
    $candidates.Add((Join-Path $env:ProgramFiles 'Git\bin\bash.exe'))
    if (${env:ProgramFiles(x86)}) {
        $candidates.Add((Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe'))
    }
    $candidates.Add((Join-Path $env:LocalAppData 'Programs\Git\bin\bash.exe'))

    foreach ($candidate in $candidates) {
        try {
            $resolved = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
        } catch {
            continue
        }
        if ($resolved -match '(?i)\\(System32|WindowsApps)\\') { continue }
        return $resolved
    }
    return $null
}

function Install-Codex {
    Write-Host ''
    Write-Info '=== Codex CLI ==='

    # 1. Install the Codex CLI via OpenAI's native installer (self-updating), mirroring the
    #    claude module's native-install decision. A failed install stops before any Codex
    #    configuration or resource projection (see Confirm-CodexCli / Confirm-ClaudeCli).
    if ($Backup) {
        Write-Info 'Backup mode — skipping Codex CLI install.'
    } elseif (-not (Confirm-CodexCli)) {
        return
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
        Source = Join-Path $Dotfiles 'ai-agents\AGENTS.md'
    }
    Copy-Dotfile @params

    # Progressive-disclosure satellite files AGENTS.md links out to on demand. Codex has no
    # directory-junction path for this dir (config.toml/AGENTS.md are copied, not symlinked),
    # so copy each file individually — same as the claude module's AGENTS.d junction covers.
    $agentsDSrc = Join-Path $Dotfiles 'ai-agents\AGENTS.d'
    if (Test-Path $agentsDSrc) {
        foreach ($file in Get-ChildItem -Path $agentsDSrc -File) {
            Copy-Dotfile -Dest (Join-Path $codexDir "AGENTS.d\$($file.Name)") -Source $file.FullName
        }
    }

    # 4. Git guardrails PreToolUse hook (issue #170) — blocks dangerous git commands (push,
    #    reset --hard, clean -f, branch -D, checkout/restore .) before Codex executes them,
    #    ported from claude/skills/git-guardrails-claude-code/scripts/block-dangerous-git.sh.
    #    User-scope, matching this repo's Claude Code guardrail scope choice. The hook script
    #    copies like any other tracked file, but ~/.codex/hooks.json is not: herdr's own
    #    installer (`herdr integration install codex`) may already own a SessionStart entry
    #    there, so a literal Copy-Dotfile would destroy it. This function actively merges both
    #    hooks.PreToolUse (this guardrail's entry) and hooks.SessionStart (the project-brain
    #    entry) — preserve any existing entries in either key that are not this install's own,
    #    and append or replace only its own entry — leaving every other event key and every
    #    other foreign entry untouched.
    $params = @{
        Dest = Join-Path $codexDir 'block-dangerous-git.sh'
        Source = Join-Path $Dotfiles 'codex\block-dangerous-git.sh'
    }
    Copy-Dotfile @params

    # 4b. AI-reference hard-block PreToolUse hook (issue #219) — same guardrail mechanism as
    #    block-dangerous-git.sh above, blocking AI/Claude/Codex/Copilot/co-authored-by references
    #    from landing in a commit, PR, or Azure Boards item. Copied alongside its own wordlist
    #    (a sibling file, read relative to the script's own directory at runtime — see
    #    ai-reference-guard.sh's header) rather than the claude module's symlink, matching this
    #    directory's existing copy-not-symlink convention (see codex/README.md).
    $params = @{
        Dest = Join-Path $codexDir 'ai-reference-guard.sh'
        Source = Join-Path $Dotfiles 'codex\ai-reference-guard.sh'
    }
    Copy-Dotfile @params
    $params = @{
        Dest = Join-Path $codexDir 'banned-ai-terms.txt'
        Source = Join-Path $Dotfiles 'ai-agents\_shared\banned-ai-terms.txt'
    }
    Copy-Dotfile @params

    $hooksJsonDest = Join-Path $codexDir 'hooks.json'
    $hooksJsonSource = Join-Path $Dotfiles 'codex\hooks.json'
    if ($Backup) {
        Write-Info 'Backup mode — skipping hooks.json merge (tracked copy is a PreToolUse/SessionStart fragment, not a full backup target).'
    } elseif ($DryRun) {
        Write-Info "[DRY RUN] would merge hooks.PreToolUse and hooks.SessionStart from $hooksJsonSource into $hooksJsonDest"
    } else {
        $sourceHooks = Get-Content -LiteralPath $hooksJsonSource -Raw | ConvertFrom-Json -AsHashtable
        # Skip only the guardrail's own PreToolUse merge when no real bash can be resolved — see
        # below. This gate must not also block the unrelated project-brain SessionStart merge:
        # session-start.ps1 is pwsh, not bash, and fails safe (exit 0) on any error, so it carries
        # none of the "broken bash path breaks every Bash call" risk the guardrail gate exists for.
        $skipGuardrailMerge = $false
        # AI-reference hard-block hook (issue #219) — same "would fail closed on every Bash
        # call if merged-but-broken" risk as the guardrail gate above, but for a different
        # cause: ai-reference-guard.sh denies unconditionally when its wordlist is missing.
        # Independent skip flag so one guardrail's install problem doesn't block the other's.
        $skipAiReferenceGuardMerge = $false
        $aiReferenceGuardSource = Join-Path $Dotfiles 'codex\ai-reference-guard.sh'
        $bannedTermsSource = Join-Path $Dotfiles 'ai-agents\_shared\banned-ai-terms.txt'
        if (-not (Test-Path -LiteralPath $aiReferenceGuardSource) -or -not (Test-Path -LiteralPath $bannedTermsSource)) {
            Write-Warn 'ai-reference-guard.sh or its wordlist not found — skipping the AI-reference PreToolUse merge (a merged-but-broken entry fails closed on every Codex Bash call). Re-run once both exist: .\setup.ps1 -Module codex'
            $skipAiReferenceGuardMerge = $true
        }
        # On Windows, rewrite each tracked `bash ~/.codex/<script>.sh` command to a resolved
        # absolute Git-for-Windows bash.exe + absolute script path — see Resolve-CodexGuardrailBash.
        # This guardrail install/rewrite is Windows/setup.ps1-only today; setup.sh does not
        # copy these scripts or merge hooks.json. Modify the source fragment's own entries
        # before they are assigned into $merged below.
        #
        # Per-hook by the SCRIPT'S OWN FILENAME, not a single hardcoded block-dangerous-git.sh
        # path: a prior version of this rewrite blindly repointed every `^bash\s` hook to
        # block-dangerous-git.sh's resolved path, which would have silently rewired
        # ai-reference-guard.sh's own entry onto the wrong script the moment a second
        # `bash ~/...` PreToolUse hook was added (issue #219).
        if ($IsWindows) {
            $bashPath = Resolve-CodexGuardrailBash
            if (-not $bashPath) {
                Write-Warn 'No Git-for-Windows bash.exe found — skipping the guardrail PreToolUse merge (a merged-but-broken guardrail entry would make every Codex Bash call fail; leaving it absent is safer). Install Git for Windows, then re-run: .\setup.ps1 -Module codex'
                $skipGuardrailMerge = $true
                $skipAiReferenceGuardMerge = $true
            } else {
                $bashPathForward = $bashPath -replace '\\', '/'
                foreach ($entry in $sourceHooks.hooks.PreToolUse) {
                    foreach ($hook in $entry.hooks) {
                        if ($hook.command -match '^bash\s+\S*[\\/](?<file>[^\\/]+)$') {
                            $scriptPath = (Join-Path $codexDir $Matches['file']) -replace '\\', '/'
                            $hook.command = "`"$bashPathForward`" `"$scriptPath`""
                        }
                    }
                }
            }
        }
        # Codex CLI executes command hooks with no shell field, so the tracked `~/...` placeholder
        # in the project-brain SessionStart entry never expands — rewrite it to the resolved
        # absolute installed script path, same reasoning as the guardrail's bash rewrite above.
        # Skills are junctioned (step 6), not copied, so the merged hook only ever resolves if
        # the tracked source script exists — check that instead of the not-yet-created junction
        # target, mirroring the guardrail branch's fail-safe pattern above.
        $skipSessionStartMerge = $false
        $sessionStartSource = Join-Path $Dotfiles 'ai-agents\skills\project-brain\scripts\session-start.ps1'
        if (-not (Test-Path -LiteralPath $sessionStartSource)) {
            Write-Warn "project-brain session-start.ps1 not found at $sessionStartSource — skipping the SessionStart merge (a merged-but-broken entry would fail every session)."
            $skipSessionStartMerge = $true
        } else {
            $sessionStartScript = Join-Path $codexDir 'skills\project-brain\scripts\session-start.ps1'
            foreach ($entry in $sourceHooks.hooks.SessionStart) {
                foreach ($hook in $entry.hooks) {
                    if ($hook.command -match 'project-brain[\\/]scripts[\\/]session-start\.ps1') {
                        $hook.command = "pwsh -NoProfile -File `"$sessionStartScript`""
                    }
                }
            }
        }

        $merged = if (Test-Path -LiteralPath $hooksJsonDest) {
            Get-Content -LiteralPath $hooksJsonDest -Raw | ConvertFrom-Json -AsHashtable
        } else {
            @{ hooks = @{} }
        }
        if (-not $merged.hooks) { $merged.hooks = @{} }

        # Two independent, sequential merge passes — one per guardrail script — so each can be
        # skipped on its own without disturbing the other's entry or any foreign entry. Each pass
        # re-reads $merged.hooks.PreToolUse (updated by the prior pass) so they compose safely.
        if (-not $skipGuardrailMerge) {
            $existingPreToolUse = if ($merged.hooks.ContainsKey('PreToolUse') -and $merged.hooks.PreToolUse) {
                @($merged.hooks.PreToolUse)
            } else {
                @()
            }
            # Filter at the individual-hook level, not the whole-entry level: an entry mixing a
            # foreign hook alongside a stale block-dangerous-git.sh hook must keep its foreign
            # hook, not lose the whole entry (mirrors the SessionStart merge below).
            $foreignEntries = foreach ($entry in $existingPreToolUse) {
                $keptHooks = @($entry.hooks | Where-Object { $_.command -notmatch 'block-dangerous-git\.sh' })
                if ($keptHooks) {
                    $entry.hooks = $keptHooks
                    $entry
                }
            }
            $dangerousGitEntries = @($sourceHooks.hooks.PreToolUse) | Where-Object {
                $_.hooks | Where-Object { $_.command -match 'block-dangerous-git\.sh' }
            }
            $merged.hooks.PreToolUse = @($foreignEntries) + @($dangerousGitEntries)
        }
        if (-not $skipAiReferenceGuardMerge) {
            $existingPreToolUse = if ($merged.hooks.ContainsKey('PreToolUse') -and $merged.hooks.PreToolUse) {
                @($merged.hooks.PreToolUse)
            } else {
                @()
            }
            # Filter at the individual-hook level, not the whole-entry level: an entry mixing a
            # foreign hook alongside a stale ai-reference-guard.sh hook must keep its foreign
            # hook, not lose the whole entry (mirrors the SessionStart merge below).
            $foreignEntries = foreach ($entry in $existingPreToolUse) {
                $keptHooks = @($entry.hooks | Where-Object { $_.command -notmatch 'ai-reference-guard\.sh' })
                if ($keptHooks) {
                    $entry.hooks = $keptHooks
                    $entry
                }
            }
            $aiReferenceEntries = @($sourceHooks.hooks.PreToolUse) | Where-Object {
                $_.hooks | Where-Object { $_.command -match 'ai-reference-guard\.sh' }
            }
            $merged.hooks.PreToolUse = @($foreignEntries) + @($aiReferenceEntries)
        }

        $existingSessionStart = if ($merged.hooks.ContainsKey('SessionStart') -and $merged.hooks.SessionStart) {
            @($merged.hooks.SessionStart)
        } else {
            @()
        }
        # Filter at the individual-hook level, not the whole-entry level: an entry mixing a
        # foreign hook alongside a project-brain hook must keep its foreign hook, not lose the
        # whole entry. (The PreToolUse merges above use the same per-hook filtering.)
        $foreignSessionStart = foreach ($entry in $existingSessionStart) {
            $keptHooks = @($entry.hooks | Where-Object { $_.command -notmatch 'project-brain[\\/]scripts[\\/]session-start\.ps1' })
            if ($keptHooks) {
                $entry.hooks = $keptHooks
                $entry
            }
        }
        $merged.hooks.SessionStart = if ($skipSessionStartMerge) {
            @($foreignSessionStart)
        } else {
            @($foreignSessionStart) + @($sourceHooks.hooks.SessionStart)
        }

        $null = Backup-Existing $hooksJsonDest
        $dir = Split-Path $hooksJsonDest
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        ($merged | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $hooksJsonDest
        $mergedKeys = @(if ((-not $skipGuardrailMerge) -or (-not $skipAiReferenceGuardMerge)) { 'hooks.PreToolUse' }) + @(if (-not $skipSessionStartMerge) { 'hooks.SessionStart' })
        if ($mergedKeys) {
            Write-Ok "Merged:     $hooksJsonDest ($($mergedKeys -join ', '))"
        } else {
            Write-Ok "Updated:    $hooksJsonDest (no keys merged — both guardrail and SessionStart merges skipped)"
        }
    }

    # 5. Register Codex as a user-scope, read-only MCP reviewer in Claude Code. User-scope MCP
    #    config lives in ~/.claude.json (settings.json does not support mcpServers), so this is
    #    a CLI registration, not a tracked file. The -c overrides pin the reviewer read-only and
    #    non-interactive regardless of ~/.codex/config.toml. Idempotent: remove any prior entry first.
    #    Requires the Claude settings file too — its absence means the claude module has not run
    #    yet, so registering now would write ahead of any other Claude-module setup.
    $claudeSettingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
    if ($Backup) {
        Write-Info 'Backup mode — skipping MCP registration.'
    } elseif (-not (Get-Command -Name claude -ErrorAction Ignore)) {
        Write-Warn 'claude CLI not found — skipping MCP registration. Install the claude module first.'
    } elseif (-not (Test-Path -LiteralPath $claudeSettingsPath)) {
        Write-Warn 'Claude settings file not found — skipping MCP registration. Install the claude module first.'
    } elseif ($DryRun) {
        Write-Info '[DRY RUN] would register user-scope MCP: claude mcp add --scope user codex -- codex mcp-server -c sandbox_mode=read-only -c approval_policy=never -c model_reasoning_effort=medium'
    } else {
        # Native command: a non-zero exit when no prior entry exists is benign and does not throw.
        & claude mcp remove --scope user codex 2>$null | Out-Null
        & claude mcp add --scope user --transport stdio codex -- codex mcp-server -c sandbox_mode=read-only -c approval_policy=never -c model_reasoning_effort=medium
        if ($LASTEXITCODE -eq 0) {
            Write-Ok 'Registered read-only Codex MCP reviewer (user scope).'
        } else {
            Write-Fail "claude mcp add failed (exit $LASTEXITCODE)."
        }
    }

    # 6. Skills — project portable and Codex-native variants into ~/.codex/skills/.
    #    Codex's own built-in skills under ~/.codex/skills/.system/ remain untouched.
    $codexSkillsDst = Join-Path $codexDir 'skills'
    if (-not (Test-Path $codexSkillsDst)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $codexSkillsDst -Force | Out-Null }
        Write-Info "Created:    $codexSkillsDst"
    }
    $portableSkills = @(Get-ChildItem -Path (Join-Path $Dotfiles 'ai-agents\skills') -Directory -ErrorAction SilentlyContinue)
    $codexSkills = @(Get-ChildItem -Path (Join-Path $Dotfiles 'codex\skills') -Directory -ErrorAction SilentlyContinue)
    $codexSkillNames = @($codexSkills.ForEach('Name'))
    $portableSkills = @($portableSkills | Where-Object { $_.Name -notin $codexSkillNames })
    # codex-review asks Codex itself for a second opinion — meaningless as self-review, so it
    # is portable everywhere except Codex.
    $portableSkills = @($portableSkills | Where-Object { $_.Name -ne 'codex-review' })
    $desiredSkillNames = @($portableSkills | ForEach-Object Name) + @($codexSkills | ForEach-Object Name)
    # Scoped to roots the Codex installer itself (current or historical) has ever written into —
    # claude\skills was the shared source Codex projected from before the ai-agents rehome, and
    # ai-agents\codex\skills was Codex's own former native root; Codex never wrote into Pi's or
    # Claude-only ai-agents\claude\skills (see issue #71).
    $managedSkillRoots = @(
        (Join-Path $Dotfiles 'ai-agents\skills'),
        (Join-Path $Dotfiles 'codex\skills'),
        (Join-Path $Dotfiles 'ai-agents\shared\skills'),
        (Join-Path $Dotfiles 'ai-agents\codex\skills'),
        (Join-Path $Dotfiles 'claude\skills')
    )
    Remove-ObsoleteManagedSkillLinks -SkillsDst $codexSkillsDst -DesiredNames $desiredSkillNames -ManagedRoots $managedSkillRoots -Runtime 'Codex'
    if ($portableSkills -or $codexSkills) {
        foreach ($skill in $portableSkills + $codexSkills) {
            $link = Join-Path $codexSkillsDst $skill.Name
            $existing = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
            if ($existing) {
                if (-not ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                    Write-Warn "Preserved unmanaged Codex skill: $link"
                    continue
                }
                $existingTarget = if ($existing.LinkTarget) { $existing.LinkTarget } else { @($existing.Target)[0] }
                $fullExistingTarget = Resolve-LinkTargetPath -Link $link -Target $existingTarget
                $isManaged = Test-ManagedSkillLink -Link $link -FullTarget $fullExistingTarget -ManagedRoots $managedSkillRoots
                if (-not $isManaged) {
                    if ($fullExistingTarget -and -not (Test-Path -LiteralPath $fullExistingTarget)) {
                        Write-Warn "Preserved unmanaged Codex skill link (target missing): $link"
                    } else {
                        Write-Warn "Preserved unmanaged Codex skill link: $link"
                    }
                    continue
                }
            }
            New-Junction -Link $link -Target $skill.FullName
        }
    } else {
        Write-Info 'No skills to install (ai-agents/skills and codex/skills are empty).'
    }

    Write-Info 'Next: run `codex login` (interactive ChatGPT-account OAuth) to authenticate.'
}

function Install-AiAgents {
    Write-Host ''
    Write-Info '=== AI Agents (composite: Claude, Codex, Pi) ==='
    # Orchestrates the existing claude/codex/pi modules without duplicating their projection
    # logic. Order matters: Install-Codex's MCP registration (step 4) gates on
    # ~/.claude/settings.json already existing, so Claude must project first.
    Install-Claude
    Install-Codex
    # Pi is the least stable of the three (npm-installed, third-party CLI) — an unanticipated
    # error here must not take down Claude/Codex projection that already ran, nor abort modules
    # listed after this one in the same invocation.
    try {
        Install-Pi
    } catch {
        Write-Fail "Pi setup failed unexpectedly: $($_.Exception.Message)"
    }
}

function Install-Serena {
    Write-Host ''
    Write-Info '=== serena (semantic code-intelligence MCP for Claude Code) ==='

    # 1. Install the serena-agent tool (idempotent) via uv, and ensure uv's tool-bin dir is on PATH
    #    so the `serena` launch command resolves in future shells. Pins Python 3.13 (uv fetches it if
    #    absent). `uv` itself comes from the winget module; under -Module all winget runs after this,
    #    so a fresh machine may need a serena re-run once uv is present. The uv check sits after
    #    $Backup/$DryRun so those no-op modes work regardless.
    if ($Backup) {
        Write-Info 'Backup mode — skipping serena install.'
    } elseif ($DryRun) {
        Write-Info '[DRY RUN] would run: uv tool install -p 3.13 serena-agent; uv tool update-shell'
    } elseif (-not (Get-Command -Name uv -ErrorAction Ignore)) {
        Write-Warn 'uv not found — install the winget module first (astral-sh.uv), then re-run.'
    } else {
        & uv tool install -p 3.13 serena-agent
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "uv tool install serena-agent failed (exit $LASTEXITCODE)."
        } else {
            & uv tool update-shell
            if ($LASTEXITCODE -eq 0) {
                Write-Ok 'Installed serena-agent (uv tool).'
            } else {
                Write-Warn "serena-agent installed, but 'uv tool update-shell' failed (exit $LASTEXITCODE) — ensure uv's tool-bin dir is on PATH or the serena MCP command won't resolve in new shells."
            }
        }
    }

    # 2. Register serena as a user-scope MCP server in Claude Code. Like the codex reviewer this is
    #    a CLI registration in ~/.claude.json (not a tracked file). --context claude-code +
    #    --project-from-cwd activate the project from each session's working dir. Idempotent.
    #    --open-web-dashboard False stops a dashboard window opening on every session start; to also
    #    tie a manually-opened dashboard's lifecycle to the session, set web_dashboard_interface: app
    #    in ~/.serena/serena_config.yml (no CLI flag exists for the interface, so it can't live here).
    if ($Backup) {
        Write-Info 'Backup mode — skipping MCP registration.'
    } elseif (-not (Get-Command -Name claude -ErrorAction Ignore)) {
        Write-Warn 'claude CLI not found — skipping MCP registration. Install the claude module first.'
    } elseif ($DryRun) {
        Write-Info '[DRY RUN] would register user-scope MCP: claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd --open-web-dashboard False'
    } else {
        # Native command: a non-zero exit when no prior entry exists is benign and does not throw.
        & claude mcp remove --scope user serena 2>$null | Out-Null
        & claude mcp add --scope user --transport stdio serena -- serena start-mcp-server --context claude-code --project-from-cwd --open-web-dashboard False
        if ($LASTEXITCODE -eq 0) {
            Write-Ok 'Registered serena MCP (user scope).'
        } else {
            Write-Fail "claude mcp add failed (exit $LASTEXITCODE)."
        }
    }
}

function Install-Context7 {
    Write-Host ''
    Write-Info '=== Context7 (up-to-date library-docs MCP for Claude Code) ==='

    # Context7 is a hosted docs service — nothing to install locally. Register it as a user-scope
    # remote HTTP MCP in Claude Code (~/.claude.json, not a tracked file), mirroring the codex/serena
    # registrations. No API key is required for basic use; set $env:CONTEXT7_API_KEY (free key from
    # context7.com/dashboard) before running to raise rate limits — it is passed as a request header
    # and lives only in ~/.claude.json, never in the repo. Idempotent: remove any prior entry first.
    if ($Backup) {
        Write-Info 'Backup mode — skipping MCP registration.'
        return
    }
    if (-not (Get-Command -Name claude -ErrorAction Ignore)) {
        Write-Warn 'claude CLI not found — skipping MCP registration. Install the claude module first.'
        return
    }

    $endpoint = 'https://mcp.context7.com/mcp'
    $addArgs  = @('mcp', 'add', '--scope', 'user', '--transport', 'http', 'context7', $endpoint)
    if ($env:CONTEXT7_API_KEY) {
        $addArgs += @('--header', "CONTEXT7_API_KEY: $env:CONTEXT7_API_KEY")
    }

    if ($DryRun) {
        $keyNote = if ($env:CONTEXT7_API_KEY) { ' (with API-key header)' } else { ' (anonymous — no API key)' }
        Write-Info "[DRY RUN] would register user-scope MCP: claude mcp add --scope user --transport http context7 $endpoint$keyNote"
        return
    }

    # Native command: a non-zero exit when no prior entry exists is benign and does not throw.
    & claude mcp remove --scope user context7 2>$null | Out-Null
    & claude @addArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "claude mcp add failed (exit $LASTEXITCODE)."
        return
    }
    if ($env:CONTEXT7_API_KEY) {
        Write-Ok 'Registered Context7 MCP (user scope, with API-key header).'
    } else {
        Write-Ok 'Registered Context7 MCP (user scope, anonymous).'
        Write-Info 'Optional: set $env:CONTEXT7_API_KEY (free key from https://context7.com/dashboard) and re-run for higher rate limits.'
    }
}

function Install-Fastmail {
    Write-Host ''
    Write-Info '=== Fastmail (official email/calendar/contacts MCP for Claude Code) ==='

    # Fastmail's official MCP server is hosted — nothing to install locally. Register it as a user-scope
    # remote HTTP MCP in Claude Code (~/.claude.json, not a tracked file), mirroring the context7/serena
    # registrations. Unlike context7 (API-key header), Fastmail authenticates via OAuth 2.0, so this
    # registers the endpoint only — the browser consent is a separate one-time `claude mcp login fastmail`
    # step (like `codex login`). Read-only vs write vs send is an access tier chosen on Fastmail's consent
    # screen; it is not a pin-able OAuth scope, so the CLI cannot enforce it. Idempotent: remove-then-add
    # rewrites only the config entry — OAuth credentials are managed separately via login/logout, so
    # re-running never silently revokes auth.
    if ($Backup) {
        Write-Info 'Backup mode — skipping MCP registration.'
        return
    }
    if (-not (Get-Command -Name claude -ErrorAction Ignore)) {
        Write-Warn 'claude CLI not found — skipping MCP registration. Install the claude module first.'
        return
    }

    $endpoint = 'https://api.fastmail.com/mcp'

    if ($DryRun) {
        Write-Info "[DRY RUN] would register user-scope MCP: claude mcp add --scope user --transport http fastmail $endpoint"
        return
    }

    # Native command: a non-zero exit when no prior entry exists is benign and does not throw.
    & claude mcp remove --scope user fastmail 2>$null | Out-Null
    & claude mcp add --scope user --transport http fastmail $endpoint
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "claude mcp add failed (exit $LASTEXITCODE)."
        return
    }
    Write-Ok 'Registered Fastmail MCP (user scope).'
    Write-Info 'Next: run `claude mcp login fastmail`, complete the browser OAuth, and choose Read-only on the consent screen.'
    Write-Info 'Then start a new session to load it. Verify with `claude mcp get fastmail`; reset auth with `claude mcp logout fastmail`.'
}

function Install-Langservers {
    Write-Host ''
    Write-Info '=== Language servers (JSON / YAML / Azure Pipelines) ==='

    # Neovim enables jsonls, yamlls and azure_pipelines_ls unconditionally (nvim/lua/config/lsp.lua),
    # so without these binaries every JSON/YAML buffer prints a spawn failure. Each package is paired
    # with the binary nvim-lspconfig's cmd actually spawns — vscode-langservers-extracted is a bundle
    # whose JSON server is the only one wired up here (its HTML/CSS/ESLint servers come along
    # incidentally), so its package and binary names differ.
    #
    # Installed through Volta, the machine's Node toolchain manager (Volta.Volta, from the winget
    # module) rather than `npm install -g`: under Volta a bare global npm install does not produce
    # working shims. Verified — all three shim cleanly into Volta's bin dir.
    $servers = @(
        @{ Package = 'vscode-langservers-extracted';    Binary = 'vscode-json-language-server'     }
        @{ Package = 'yaml-language-server';            Binary = 'yaml-language-server'            }
        @{ Package = 'azure-pipelines-language-server'; Binary = 'azure-pipelines-language-server' }
    )

    if ($Backup) {
        Write-Info 'Backup mode — skipping language-server install.'
        return
    }

    # The dry run reports which packages this module OWNS, not which the machine happens to have,
    # so it stays deterministic once they are installed. Hence it sits ahead of both the volta
    # lookup and the per-package presence check below — unlike Install-Bat, whose dry-run output
    # is deliberately machine-dependent.
    if ($DryRun) {
        foreach ($server in $servers) {
            Write-Info "[DRY RUN] would run: volta install $($server.Package)"
        }
        return
    }

    # Warn and skip, never fail: one missing toolchain must not abort an otherwise good -Module all.
    if (-not (Get-Command -Name volta -ErrorAction Ignore)) {
        Write-Warn 'volta not found — install the winget module first (Volta.Volta), then re-run this module.'
        return
    }

    foreach ($server in $servers) {
        if (Get-Command -Name $server.Binary -ErrorAction Ignore) {
            Write-Ok "Language server: $($server.Binary) (already installed)"
            continue
        }
        & volta install $server.Package
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Language server: installed $($server.Package)"
        } else {
            Write-Fail "volta install $($server.Package) failed (exit $LASTEXITCODE)."
        }
    }
}

function Install-BicepTools {
    Write-Host ''
    Write-Info '=== Bicep tools (language server) ==='

    # Microsoft publishes the Bicep language server as a .NET global tool (learn.microsoft.com/
    # azure/azure-resource-manager/bicep/install), documented for AI coding tools and other LSP
    # clients — this is binary-only: it installs bicep-ls and nothing else. Agent registration
    # (Claude/Codex/Pi) is a separate, later slice; see .agents/specs/bicep-code-intelligence.md.
    $package = 'Azure.Bicep.LangServer'

    if ($Backup) {
        Write-Info 'Backup mode — skipping Bicep tools install.'
        return
    }

    if ($DryRun) {
        Write-Info "[DRY RUN] would run: dotnet tool install --global $package"
        return
    }

    # Warn and skip, never fail: one missing toolchain must not abort an otherwise good -Module all.
    # On a bare machine the winget module only PRINTS the .NET SDK bootstrap command — it installs
    # nothing — so `dotnet` is absent until winget/packages.ps1 has actually been run; a re-run of
    # this module afterwards picks it up, same as the langservers/Volta two-run caveat.
    if (-not (Get-Command -Name dotnet -ErrorAction Ignore)) {
        Write-Warn 'dotnet not found — install the winget module first (the .NET SDK), then re-run this module.'
        return
    }

    # Idempotency via `dotnet tool list --global`, not `Get-Command bicep-ls` — a PATH probe
    # conflates "installed" with "discoverable in this shell", so a rerun in a shell with a stale
    # PATH would attempt a reinstall of an already-installed tool.
    $installedTools = & dotnet tool list --global 2>$null | Out-String
    if ($installedTools -match [regex]::Escape($package.ToLowerInvariant())) {
        Write-Ok "Bicep language server: $package (already installed)"
        return
    }

    & dotnet tool install --global $package
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Bicep language server: installed $package"
    } else {
        Write-Fail "dotnet tool install --global $package failed (exit $LASTEXITCODE)."
    }
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
        'psmux'      { Install-Psmux      }
        'herdr'      { Install-Herdr      }
        'yazi'       { Install-Yazi       }
        'curl'       { Install-Curl       }
        'winget'     { Install-Winget     }
        'vscode'     { Install-VSCode     }
        'bat'        { Install-Bat        }
        'claude'     { Install-Claude     }
        'codex'      { Install-Codex      }
        'pi'         { Install-Pi         }
        'ai-agents'  { Install-AiAgents   }
        'serena'     { Install-Serena     }
        'context7'   { Install-Context7   }
        'fastmail'   { Install-Fastmail   }
        'langservers' { Install-Langservers }
        'biceptools'  { Install-BicepTools  }
        'lazygit'        { Install-Lazygit        }
        'windowsterminal' { Install-WindowsTerminal }
        default          { Write-Warn "Unknown module '$m' — skipping." }
    }
}

if ($CleanBackups) { Remove-OldBackups }

Write-Host ''
Write-Ok 'Done.'
if ($Backup -and -not $DryRun) { Write-Info "Review the captured drift: git -C `"$Dotfiles`" diff" }
