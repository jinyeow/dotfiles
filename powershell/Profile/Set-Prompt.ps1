# ============================================================================
# Set-Prompt.ps1 — Event-driven prompt with sync git + async Az context
# ============================================================================
# Git:  synchronous (fast enough for interactive use)
# Az:   async via long-lived runspace, refreshed every 60 seconds
# ============================================================================

# --- Computed-once constants ------------------------------------------------
$global:PromptConst = @{
    IsAdmin = ([System.Security.Principal.WindowsPrincipal](
        [System.Security.Principal.WindowsIdentity]::GetCurrent()
    )).IsInRole('Administrators')

    # ANSI escape sequences
    ESC          = [char]27
    Reset        = "`e[0m"
    Bold         = "`e[1m"
    Blue         = "`e[34m"
    BrightBlue   = "`e[94m"
    Red          = "`e[91m"
    Green        = "`e[92m"
    Yellow       = "`e[93m"
    Cyan         = "`e[36m"
    Magenta      = "`e[95m"
    BrightCyan   = "`e[96m"
    Grey         = "`e[37m"
    White        = "`e[97m"
    DimWhite     = "`e[37;2m"

    # Prompt settings
    MaxPathLength   = 50   # upper cap; the prompt scales this to ~1/3 of pane width
    MaxBranchLength = 35
    ShowWorktree    = $true
    ShowUsername     = $true
    ShowJj          = $true   # jj (Jujutsu) takes precedence over git in colocated repos
}

# --- Az context async infrastructure ---------------------------------------
$global:PromptCache = @{
    AzContext       = $null       # cached result hashtable
    AzRunspace      = $null       # runspace info hashtable
    AzTimerDisposed = $false
}

function Start-AzContextRefresh {
    <#
    .SYNOPSIS
    Fires a background runspace to fetch Get-AzContext. Non-blocking.
    Safe to call repeatedly — disposes previous runspace if still running.
    #>

    # Bail if Az.Accounts isn't available
    if (-not $global:ProfileModules['Az.Accounts']) { return }

    # Clean up previous if exists
    if ($global:PromptCache.AzRunspace) {
        try {
            $global:PromptCache.AzRunspace.PowerShell.Stop()
            $global:PromptCache.AzRunspace.PowerShell.Dispose()
            $global:PromptCache.AzRunspace.Runspace.Dispose()
        } catch {}
        $global:PromptCache.AzRunspace = $null
    }

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    # UseLocalScope = $true to prevent variable scope creep
    $null = $ps.AddScript({
        try {
            Import-Module Az.Accounts -ErrorAction Stop
            $ctx = Get-AzContext -ErrorAction Stop
            if ($ctx) {
                @{
                    Account      = $ctx.Account.Id
                    Subscription = $ctx.Subscription.Name
                    TenantId     = $ctx.Tenant.Id
                    Environment  = $ctx.Environment.Name
                    Timestamp    = [datetime]::Now
                }
            }
        } catch {
            $null
        }
    }, $true)

    $handle = $ps.BeginInvoke()

    $global:PromptCache.AzRunspace = @{
        PowerShell = $ps
        Runspace   = $runspace
        Handle     = $handle
    }
}

function Update-AzPrompt {
    <#
    .SYNOPSIS
    Manually trigger an Az context refresh. Call after Connect-AzAccount.
    #>
    Start-AzContextRefresh
    Write-Host 'Az context refresh triggered.' -ForegroundColor Cyan
}

function Get-AzAsyncResult {
    <#
    .SYNOPSIS
    Non-blocking check for Az context result. Returns cached value if not ready.
    #>
    $info = $global:PromptCache.AzRunspace
    if (-not $info) { return $global:PromptCache.AzContext }

    if ($info.Handle.IsCompleted) {
        try {
            $result = $info.PowerShell.EndInvoke($info.Handle)
            if ($result) {
                $global:PromptCache.AzContext = $result
            }
        } catch {} finally {
            try {
                $info.PowerShell.Dispose()
                $info.Runspace.Dispose()
            } catch {}
            $global:PromptCache.AzRunspace = $null
        }
    }

    return $global:PromptCache.AzContext
}

# --- Az context auto-refresh timer (60s) ------------------------------------
function Initialize-AzTimer {
    # Idempotent: unregister existing before re-registering
    # NOTE: Get-EventSubscriber -SourceIdentifier does NOT support wildcards,
    #       so we filter with Where-Object. Use -Force to find -SupportEvent subs.
    Get-EventSubscriber -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.SourceIdentifier -like 'Profile.Az*' } |
        Unregister-Event -Force

    # Dispose previous timer object if reloading profile
    if ($global:PromptCache.AzTimer) {
        $global:PromptCache.AzTimer.Stop()
        $global:PromptCache.AzTimer.Dispose()
        $global:PromptCache.AzTimer = $null
    }

    if (-not $global:ProfileModules['Az.Accounts']) { return }

    $timer = [System.Timers.Timer]::new(60000)  # 60 seconds
    $timer.AutoReset = $true

    # The -Action scriptblock of Register-ObjectEvent runs in a separate runspace
    # and cannot see functions from the main session. We bridge back via New-Event
    # which fires a custom engine event handled by Register-EngineEvent below.
    Register-ObjectEvent -InputObject $timer -EventName Elapsed `
        -SourceIdentifier 'Profile.AzTimer.Elapsed' `
        -Action { New-Event -SourceIdentifier 'Profile.AzRefreshRequested' } `
        -SupportEvent | Out-Null

    # This handler runs in the main session where Start-AzContextRefresh is visible
    Register-EngineEvent -SourceIdentifier 'Profile.AzRefreshRequested' `
        -Action { Start-AzContextRefresh } | Out-Null

    $timer.Start()
    $global:PromptCache.AzTimer = $timer

    # Fire initial refresh immediately
    Start-AzContextRefresh
}

# Clean up on exit (idempotent for . $PROFILE reloads)
# -SupportEvent subscribers are hidden; -Force is required to find and unregister them
Get-EventSubscriber -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.SourceIdentifier -eq 'PowerShell.Exiting' -and $_.SupportEvent } |
    Unregister-Event -Force
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    if ($global:PromptCache.AzTimer) {
        $global:PromptCache.AzTimer.Stop()
        $global:PromptCache.AzTimer.Dispose()
    }
    if ($global:PromptCache.AzRunspace) {
        try {
            $global:PromptCache.AzRunspace.PowerShell.Stop()
            $global:PromptCache.AzRunspace.PowerShell.Dispose()
            $global:PromptCache.AzRunspace.Runspace.Dispose()
        } catch {}
    }
} -SupportEvent | Out-Null

# --- Git helpers (synchronous) ----------------------------------------------
function Get-GitPromptInfo {
    <#
    .SYNOPSIS
    Returns a hashtable with git status info, or $null if not in a repo.
    All git calls are synchronous — fast enough for interactive prompt.
    Uses up to 4 git processes: rev-parse (gate), rev-parse (top-level),
    rev-list, status. The top-level call only runs when the gate passes.
    #>

    # Gate: branch + git-dir + git-common-dir. Works in bare repos, so it doubles
    # as the "are we in a repo" check. --show-toplevel is deliberately NOT here:
    # it errors in a bare repo and would wipe the whole git segment.
    $revParts = git rev-parse --abbrev-ref HEAD --git-dir --git-common-dir 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $revParts) { return $null }

    # rev-parse returns one value per line
    $revLines = @($revParts)
    $branch       = $revLines[0]
    $gitDir       = if ($revLines.Count -gt 1) { $revLines[1] } else { $null }
    $gitCommonDir = if ($revLines.Count -gt 2) { $revLines[2] } else { $null }

    # Repo top-level for truncate-to-repo. Separate call because --show-toplevel
    # errors in a bare repo; tolerate that and leave TopLevel null there. Only
    # runs when the gate passed, so non-repo dirs pay nothing for it.
    $topLevel = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { $topLevel = $null }

    $info = @{
        Branch     = $branch
        IsWorktree = $false
        # git emits forward slashes; normalise to the platform separator so the
        # truncate-to-repo prefix match against $PWD.Path works on Windows.
        TopLevel   = if ($topLevel) { $topLevel.Replace('/', [IO.Path]::DirectorySeparatorChar) } else { $null }
        Ahead      = 0
        Behind     = 0
        Staged     = 0
        Modified   = 0
        Deleted    = 0
        Untracked  = 0
        Conflicts  = 0
        Renamed    = 0
        HasChanges = $false
    }

    # Worktree detection: git-dir differs from git-common-dir in linked worktrees
    if ($gitDir -and $gitCommonDir -and ($gitDir -ne $gitCommonDir)) {
        $info.IsWorktree = $true
    }

    # Ahead/behind
    $ab = git rev-list --left-right --count '@{upstream}...HEAD' 2>$null
    if ($LASTEXITCODE -eq 0 -and $ab -match '(\d+)\s+(\d+)') {
        $info.Behind = [int]$Matches[1]
        $info.Ahead  = [int]$Matches[2]
    }

    # Porcelain status parse
    $status = git status --porcelain 2>$null
    if ($status) {
        $info.HasChanges = $true
        foreach ($line in $status) {
            if ($line.Length -lt 2) { continue }
            $idx = $line[0]
            $wt  = $line[1]

            # Untracked
            if ($idx -eq '?' -and $wt -eq '?') { $info.Untracked++; continue }

            # Conflicts (unmerged)
            if ($idx -in 'U','A','D' -and $wt -in 'U','A','D') { $info.Conflicts++; continue }

            # Staged
            switch ($idx) {
                'M' { $info.Staged++ }
                'A' { $info.Staged++ }
                'D' { $info.Staged++ }
                'R' { $info.Renamed++ }
            }

            # Working tree
            switch ($wt) {
                'M' { $info.Modified++ }
                'D' { $info.Deleted++ }
            }
        }
    }

    return $info
}

# --- jj (Jujutsu) helpers (synchronous) -------------------------------------
function Find-JjRoot {
    <#
    .SYNOPSIS
    Walks up from $StartPath looking for a `.jj` directory and returns the
    containing dir (the workspace root), or $null. Pure filesystem — no process
    spawn — so non-jj directories pay nothing. Handles subdirectories correctly
    (unlike a naive `.jj`-in-PWD check) and doubles as the truncate-to-repo anchor.
    #>
    param([string]$StartPath)
    $dir = $StartPath
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir '.jj') -PathType Container) { return $dir }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Get-JjPromptInfo {
    <#
    .SYNOPSIS
    Returns a hashtable of jj working-copy (@) status, or $null if not in a jj
    repo. Uses up to 3 jj processes, only inside a jj repo (the gate is a
    filesystem walk): @ info, closest-bookmark name, bookmark→@ distance. All
    calls pass --ignore-working-copy so the prompt never
    triggers a working-copy snapshot (a write); the tradeoff is that FileCount
    and Empty reflect the last snapshot jj took, not un-snapshotted editor edits.
    #>
    $root = Find-JjRoot -StartPath $PWD.Path
    if (-not $root) { return $null }

    # Single template for @: change-id, conflict, empty, has-description, file
    # count — tab-separated on one line.
    $tpl = 'change_id.shortest(8) ++ "\t" ++ if(conflict,"1","0") ++ "\t" ++ ' +
           'if(empty,"1","0") ++ "\t" ++ if(description,"1","0") ++ "\t" ++ ' +
           'self.diff().files().len()'
    $raw = jj log --ignore-working-copy --no-graph --color never --limit 1 -r '@' -T $tpl 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) { return $null }

    $f = ([string]$raw).Split("`t")
    if ($f.Count -lt 5) { return $null }

    # Parse defensively — a prompt must never throw, so never let a bad cast bubble
    $fileCount = 0
    [void][int]::TryParse($f[4], [ref]$fileCount)

    $info = @{
        Root              = $root
        ChangeId          = $f[0]
        Conflict          = $f[1] -eq '1'
        Empty             = $f[2] -eq '1'
        HasDesc           = $f[3] -eq '1'
        FileCount         = $fileCount
        Bookmark          = ''
        BookmarkDistance  = 0
    }

    # Closest ancestor bookmark — the branch-like pointer @ is working ahead of.
    # `bookmarks` on @ is usually empty (anonymous changes), so resolve the nearest
    # bookmarked ancestor instead, the way git shows the branch you're on.
    $closest = 'heads(::@ & bookmarks())'
    $bm = jj log --ignore-working-copy --no-graph --color never --limit 1 -r $closest -T 'bookmarks.join(",")' 2>$null
    if ($LASTEXITCODE -eq 0 -and $bm) {
        $info.Bookmark = [string]$bm
        # Commits between that bookmark and @ (one 'x' per rev). Only meaningful
        # when a bookmark exists; an empty left side would match all ancestors.
        # -join '' collapses any multi-line capture into one string so the char
        # count is the rev count regardless of how the native command is captured.
        $dist = (jj log --ignore-working-copy --no-graph --color never -r "$closest..@" -T '"x"' 2>$null) -join ''
        if ($LASTEXITCODE -eq 0 -and $dist) { $info.BookmarkDistance = $dist.Length }
    }

    $info.HasChanges = ($info.FileCount -gt 0) -or $info.Conflict
    return $info
}

# --- Path shortening --------------------------------------------------------
function Test-PathUnder {
    <#
    .SYNOPSIS
    True if $Path equals $Base or is a descendant of it, matching only on a
    directory-separator boundary so e.g. C:\src\repo2 does NOT match C:\src\repo.
    #>
    param([string]$Path, [string]$Base)
    if (-not $Base) { return $false }
    $sep = [IO.Path]::DirectorySeparatorChar
    if ($Path.Equals($Base, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $Path.StartsWith($Base.TrimEnd($sep) + $sep, [StringComparison]::OrdinalIgnoreCase)
}

function Get-ShortenedPath {
    <#
    .SYNOPSIS
    Responsive path shortening, anchored at the git repo root when inside one
    (truncate-to-repo). Leading components are abbreviated to their first
    character left-to-right, only as far as needed to fit MaxLength; the anchor
    (repo leaf / drive / ~) and the current (last) folder are always kept full.
    e.g. outside a repo: ~\Personal Projects\dotfiles\powershell -> ~\P\...\powershell
         inside a repo:  E:\Personal Projects\dotfiles\powershell\Profile -> dotfiles\powershell\Profile
    #>
    param(
        [int]$MaxLength = 30,
        [string]$RepoRoot
    )

    $sep  = [IO.Path]::DirectorySeparatorChar
    $path = $PWD.Path

    if ($RepoRoot -and (Test-PathUnder $path $RepoRoot)) {
        # truncate-to-repo: anchor at the repo-root leaf, drop everything above it
        $repoLeaf = Split-Path $RepoRoot -Leaf
        $rel      = $path.Substring($RepoRoot.Length).TrimStart($sep)
        $path     = if ($rel) { "${repoLeaf}${sep}${rel}" } else { $repoLeaf }
    }
    elseif (Test-PathUnder $path $HOME) {
        $path = '~' + $path.Substring($HOME.Length)
    }

    if ($path.Length -le $MaxLength) { return $path }

    $parts = $path.Split($sep)

    # Only an anchor + folder (or less): nothing meaningful to abbreviate
    if ($parts.Count -le 2) { return $path }

    # Abbreviate leading segments left-to-right, stopping as soon as it fits.
    # Hidden dirs keep their leading dot (.config -> .c) so they stay recognisable.
    for ($i = 1; $i -lt $parts.Count - 1; $i++) {
        $seg = $parts[$i]
        if ([string]::IsNullOrEmpty($seg)) { continue }  # UNC leading '\\' empties
        $parts[$i] = if ($seg.StartsWith('.') -and $seg.Length -gt 1) { $seg.Substring(0, 2) }
                     else { $seg.Substring(0, 1) }
        if (($parts -join $sep).Length -le $MaxLength) { break }
    }

    return $parts -join $sep
}

function Get-ShortenedBranch {
    param([string]$Branch, [int]$MaxLength = 35)
    if (-not $Branch -or $Branch.Length -le $MaxLength) { return $Branch }
    $keep = [Math]::Floor($MaxLength / 2) - 2
    return $Branch.Substring(0, $keep) + '...' + $Branch.Substring($Branch.Length - $keep)
}

# --- Prompt function --------------------------------------------------------
function prompt {
    # Capture immediately before any commands corrupt these
    $lastSuccess = $?
    $savedExit   = $LASTEXITCODE

    $c = $global:PromptConst
    $out = [System.Text.StringBuilder]::new(256)

    # --- CWD tracking ---
    $loc = Get-Location
    if ($loc.Provider.Name -eq 'FileSystem') {
        # Sync the Win32 process CWD so Zellij opens new panes in this directory
        # (pwsh's Set-Location only moves its provider, not the process CWD).
        if ($loc.ProviderPath -ne [System.Environment]::CurrentDirectory) {
            try { [System.Environment]::CurrentDirectory = $loc.ProviderPath }
            catch [System.IO.IOException] { }  # cwd deleted or UNC — leave process CWD as-is
        }
        # Windows Terminal CWD tracking (OSC 9;9)
        $null = $out.Append("$($c.ESC)]9;9;`"$($loc.ProviderPath)`"$($c.ESC)\")
    }

    # --- Line 1: user path git az ---

    # Username
    if ($c.ShowUsername) {
        $null = $out.Append("$($c.Blue)$([Environment]::UserName)$($c.Reset) ")
    }

    # VCS (computed before the path so the path can anchor at the repo root).
    # jj takes precedence: in a colocated repo git would show a detached HEAD,
    # so when a jj repo is detected we skip git entirely.
    $jj  = if ($c.ShowJj) { Get-JjPromptInfo } else { $null }
    $git = if ($jj) { $null } else { Get-GitPromptInfo }

    # Path — width-relative budget (~1/3 of the pane), capped, with a sane floor.
    # Anchored at the repo root when inside one (truncate-to-repo).
    $width = try { [Console]::WindowWidth } catch { 0 }
    $pathMax = if ($width -gt 0) {
        [Math]::Max(20, [Math]::Min($c.MaxPathLength, [int]($width / 3)))
    } else { $c.MaxPathLength }
    $repoRoot  = if ($jj) { $jj.Root } elseif ($git) { $git.TopLevel } else { $null }
    $shortPath = Get-ShortenedPath -MaxLength $pathMax -RepoRoot $repoRoot
    $null = $out.Append("in $($c.Green)$shortPath$($c.Reset) ")

    # jj (Jujutsu) — change-id is the stable identity; bookmarks are the
    # branch-like pointers. Rendered instead of git when a jj repo is detected.
    if ($jj) {
        # change-id always BrightCyan so jj is visually distinct from git's ±
        $null = $out.Append("$($c.BrightCyan)jj:$($jj.ChangeId)$($c.Reset)")

        # Closest bookmark (branch-like); colour mirrors git: red when dirty
        if ($jj.Bookmark) {
            $bmColor = if ($jj.HasChanges) { $c.Red } else { $c.Yellow }
            $bm = Get-ShortenedBranch -Branch $jj.Bookmark -MaxLength $c.MaxBranchLength
            $null = $out.Append(" ${bmColor}${bm}$($c.Reset)")
        }

        # Commits ahead of that bookmark
        if ($jj.BookmarkDistance -gt 0) {
            $null = $out.Append(" $($c.Green)↑$($jj.BookmarkDistance)$($c.Reset)")
        }

        # State indicators
        $jjInd = [System.Text.StringBuilder]::new(32)
        if ($jj.Conflict)        { $null = $jjInd.Append(" $($c.Red)!$($c.Reset)") }
        if ($jj.FileCount -gt 0) { $null = $jjInd.Append(" $($c.Yellow)*$($jj.FileCount)$($c.Reset)") }
        if ($jj.Empty)           { $null = $jjInd.Append(" $($c.DimWhite)∅$($c.Reset)") }
        if (-not $jj.HasDesc)    { $null = $jjInd.Append(" $($c.Magenta)✎$($c.Reset)") }
        $null = $out.Append($jjInd.ToString())

        $null = $out.Append(' ')
    }
    # Git
    elseif ($git -and $git.Branch) {
        $branchDisplay = Get-ShortenedBranch -Branch $git.Branch -MaxLength $c.MaxBranchLength
        $branchColor = if ($git.HasChanges) { $c.Red } else { $c.Yellow }

        # wt: prefix for worktrees, ± for normal repos
        if ($c.ShowWorktree -and $git.IsWorktree) {
            $null = $out.Append("${branchColor}wt:${branchDisplay}$($c.Reset)")
        } else {
            $null = $out.Append("${branchColor}±${branchDisplay}$($c.Reset)")
        }

        # Upstream indicators
        if ($git.Ahead -gt 0 -and $git.Behind -gt 0) {
            $null = $out.Append(" $($c.Yellow)↕$($c.Reset)")
        } elseif ($git.Ahead -gt 0) {
            $null = $out.Append(" $($c.Green)↑$($git.Ahead)$($c.Reset)")
        } elseif ($git.Behind -gt 0) {
            $null = $out.Append(" $($c.Red)↓$($git.Behind)$($c.Reset)")
        }

        # File status
        $indicators = [System.Text.StringBuilder]::new(32)
        if ($git.Conflicts -gt 0) { $null = $indicators.Append(" $($c.Red)!$($git.Conflicts)$($c.Reset)") }
        if ($git.Staged -gt 0)    { $null = $indicators.Append(" $($c.Green)+$($git.Staged)$($c.Reset)") }
        if ($git.Modified -gt 0)  { $null = $indicators.Append(" $($c.Yellow)*$($git.Modified)$($c.Reset)") }
        if ($git.Deleted -gt 0)   { $null = $indicators.Append(" $($c.Red)-$($git.Deleted)$($c.Reset)") }
        if ($git.Renamed -gt 0)   { $null = $indicators.Append(" $($c.BrightCyan)R$($git.Renamed)$($c.Reset)") }
        if ($git.Untracked -gt 0) { $null = $indicators.Append(" $($c.Magenta)?$($git.Untracked)$($c.Reset)") }
        $null = $out.Append($indicators.ToString())

        $null = $out.Append(' ')
    }

    # --- Line 2 (conditional): Az context + background jobs ---
    # Only shown when there's something to display
    $contextLine = [System.Text.StringBuilder]::new(64)

    # Az context (non-blocking read of async result)
    $az = Get-AzAsyncResult
    if ($az -and $az.Subscription) {
        $null = $contextLine.Append("$($c.BrightBlue)☁$($c.Reset) ")
        $null = $contextLine.Append("$($c.Cyan)$($az.Subscription)$($c.Reset) ")
    }

    # Background jobs count
    $runningJobs = @(Get-Job -State Running).Count
    if ($runningJobs -gt 0) {
        $null = $contextLine.Append("$($c.Yellow)⚙ ${runningJobs}$($c.Reset) ")
    }

    if ($contextLine.Length -gt 0) {
        $null = $out.Append("`n")
        $null = $out.Append($contextLine.ToString())
    }

    # --- Final line: duration status promptchar ---
    $null = $out.Append("`n")

    # Last command duration
    $lastCmd = Get-History -Count 1
    if ($lastCmd) {
        $ms = $lastCmd.Duration.TotalMilliseconds
        if ($ms -ge 60000) {
            $timeStr = "$($lastCmd.Duration.TotalMinutes.ToString('#.##'))m"
            $timeColor = $c.Red
        } elseif ($ms -ge 1000) {
            $timeStr = "$($lastCmd.Duration.TotalSeconds.ToString('#.##'))s"
            $timeColor = $c.Red
        } elseif ($ms -ge 250) {
            $timeStr = "$($ms.ToString('#'))ms"
            $timeColor = $c.Yellow
        } else {
            $timeStr = "$($ms.ToString('#'))ms"
            $timeColor = $c.Green
        }
        $null = $out.Append("$($c.DimWhite)[${timeColor}${timeStr}$($c.DimWhite)]$($c.Reset) ")
    }

    # Exit status
    if (-not $lastSuccess) {
        if ($savedExit -and $savedExit -ne 0) {
            $null = $out.Append("$($c.Red)✗ $savedExit$($c.Reset) ")
        } else {
            $null = $out.Append("$($c.Red)✗$($c.Reset) ")
        }
    } else {
        $null = $out.Append("$($c.Green)✓$($c.Reset) ")
    }

    # Prompt character
    $promptChar = if ($c.IsAdmin) { '#' } else { '$' }
    $null = $out.Append("$($c.White)$($promptChar * ($NestedPromptLevel + 1))$($c.Reset) ")

    # Restore LASTEXITCODE so git calls in the prompt don't leak
    $global:LASTEXITCODE = $savedExit

    return $out.ToString()
}

# --- Initialize async Az context -------------------------------------------
Initialize-AzTimer
