# ============================================================================
# Set-Prompt.ps1 — Event-driven prompt with sync git + async Az context
# ============================================================================
# Git:  synchronous (fast enough for interactive use)
# Az:   async via long-lived runspace, refreshed every 60 seconds
# ============================================================================

# --- Computed-once constants ------------------------------------------------
$global:PromptConst = @{
    # WindowsIdentity/WindowsPrincipal throw PlatformNotSupportedException off
    # Windows, so gate the admin check on $IsWindows. On Linux/macOS root is uid 0.
    IsAdmin = if ($IsWindows) {
        ([System.Security.Principal.WindowsPrincipal](
            [System.Security.Principal.WindowsIdentity]::GetCurrent()
        )).IsInRole('Administrators')
    } elseif (Get-Command id -ErrorAction Ignore) {
        (id -u) -eq '0'
    } else {
        $false
    }

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
# Guarded so `. $PROFILE` reuses the live long-lived runspace/timer instead of
# orphaning them (a fresh hashtable would strand the open runspace and its Az
# import, not just the timer).
if (-not $global:PromptCache) {
    $global:PromptCache = @{
        AzContext       = $null   # cached result hashtable
        AzRunspace      = $null   # persistent [runspace], opened once and reused
        AzInvocation    = $null   # per-tick @{ PowerShell; Handle } on that runspace
    }
}

function Start-AzContextRefresh {
    <#
    .SYNOPSIS
    Fires a background invocation to fetch Get-AzContext on a long-lived runspace.
    Non-blocking. Safe to call repeatedly: the runspace and its Az.Accounts import
    are paid once, so a per-tick refresh runs only Get-AzContext.
    #>

    # Bail if Az.Accounts isn't available
    if (-not $global:ProfileModules['Az.Accounts']) { return }

    # Concurrency guard: a runspace runs only ONE pipeline at a time. If the previous
    # invocation is still running, skip this tick (starting a second pipeline on the
    # busy runspace throws "runspace is already in use"). If it finished, dispose it.
    if ($global:PromptCache.AzInvocation) {
        if (-not $global:PromptCache.AzInvocation.Handle.IsCompleted) { return }
        try { $global:PromptCache.AzInvocation.PowerShell.Dispose() } catch {}
        $global:PromptCache.AzInvocation = $null
    }

    # Ensure the persistent runspace exists and is usable; recreate only when it is
    # absent or broken. A bare runspace opens in ~10ms; the Az.Accounts import is done
    # once by the priming invocation below (kept off the main thread — see $created).
    $runspace = $global:PromptCache.AzRunspace
    $created  = $false
    if (-not $runspace -or $runspace.RunspaceStateInfo.State -eq 'Broken') {
        if ($runspace) { try { $runspace.Dispose() } catch {} }
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()
        $global:PromptCache.AzRunspace = $runspace
        $created = $true
    }

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    # Per-tick script: module already loaded in the runspace's session state.
    $tick = {
        try {
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
    }

    # One-time priming invocation on a freshly (re)created runspace: import the module
    # once, then read the context. Import stays async here (never on the main thread);
    # it persists in the runspace's session state for every later Get-AzContext tick.
    $prime = {
        try {
            Import-Module Az.Accounts -ErrorAction Stop
        } catch {
            # Signal an import failure distinctly: the caller drops this runspace so
            # the next refresh recreates and re-primes it, rather than ticking forever
            # on a healthy-but-unprimed session where every Get-AzContext would fail.
            return @{ PrimeFailed = $true }
        }
        try {
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
    }

    # UseLocalScope = $true to prevent variable scope creep
    $null = $ps.AddScript($(if ($created) { $prime } else { $tick }), $true)

    $handle = $ps.BeginInvoke()

    $global:PromptCache.AzInvocation = @{
        PowerShell = $ps
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
    $info = $global:PromptCache.AzInvocation
    if (-not $info) { return $global:PromptCache.AzContext }

    if ($info.Handle.IsCompleted) {
        try {
            $result = $info.PowerShell.EndInvoke($info.Handle)
            if ($result -and $result.PrimeFailed) {
                # Priming import failed — drop the runspace so the next refresh
                # recreates and re-primes it instead of ticking on a dead session.
                try { $global:PromptCache.AzRunspace.Dispose() } catch {}
                $global:PromptCache.AzRunspace = $null
            } elseif ($result) {
                $global:PromptCache.AzContext = $result
            }
        } catch {} finally {
            # Dispose only the per-tick PowerShell; the runspace is long-lived.
            try { $info.PowerShell.Dispose() } catch {}
            $global:PromptCache.AzInvocation = $null
        }
    }

    return $global:PromptCache.AzContext
}

# --- Az context auto-refresh timer (60s) ------------------------------------
function Initialize-AzTimer {
    # Idempotent: unregister existing before re-registering. Runs *before* the Az
    # guard so a reload never leaves a stale PowerShell.Exiting handler behind when
    # Az has since become unavailable (the guard would otherwise return early).
    # NOTE: Get-EventSubscriber -SourceIdentifier does NOT support wildcards, so we
    #       filter with Where-Object. -Force finds hidden -SupportEvent subscribers.
    # The PowerShell.Exiting clause is narrowed to THIS profile's own handler (its
    # action body references $global:PromptCache.Az*) — an unqualified match would
    # unregister every module's hidden Exiting handler on a `. $PROFILE` reload.
    Get-EventSubscriber -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.SourceIdentifier -like 'Profile.Az*' -or
                       ($_.SourceIdentifier -eq 'PowerShell.Exiting' -and $_.SupportEvent -and
                        $_.Action -and $_.Action.Command -match 'PromptCache\.Az') } |
        Unregister-Event -Force

    # Dispose previous timer object if reloading profile
    if ($global:PromptCache.AzTimer) {
        $global:PromptCache.AzTimer.Stop()
        $global:PromptCache.AzTimer.Dispose()
        $global:PromptCache.AzTimer = $null
    }

    if (-not $global:ProfileModules['Az.Accounts']) { return }

    # Clean up timer + runspace on shell exit. Registered here (Phase 2a, when the
    # timer is created) rather than at profile load — the first eventing call pays
    # the eventing-subsystem init (~86ms cold), so keeping it off Phase 1 leaves
    # only the mandatory OnIdle registration to absorb that one-time cost. The
    # matching unregister lives in the top cleanup block above (before the guard).
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        if ($global:PromptCache.AzTimer) {
            $global:PromptCache.AzTimer.Stop()
            $global:PromptCache.AzTimer.Dispose()
        }
        if ($global:PromptCache.AzInvocation) {
            try {
                $global:PromptCache.AzInvocation.PowerShell.Stop()
                $global:PromptCache.AzInvocation.PowerShell.Dispose()
            } catch {}
        }
        if ($global:PromptCache.AzRunspace) {
            try { $global:PromptCache.AzRunspace.Dispose() } catch {}
        }
    } -SupportEvent | Out-Null

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

# --- Git helpers (synchronous) ----------------------------------------------
function Get-GitPromptInfo {
    <#
    .SYNOPSIS
    Returns a hashtable with git status info, or $null if not in a repo.
    All git calls are synchronous — fast enough for interactive prompt.
    Uses 4 git processes: rev-parse (gate + top-level), branch (name),
    rev-list (ahead/behind), status. In a bare repo the gate errors on
    --show-toplevel and retries without it (5 processes), which is the rare path.
    #>

    # Gate + top-level in one rev-parse. --show-toplevel is first so it is line 0.
    # This whole call errors (exit 128) in a bare repo — no work tree — so on failure
    # retry without it: a bare repo still registers as a repo and TopLevel stays null.
    # --show-toplevel/--git-dir succeed on an UNBORN branch (fresh `git init`, no
    # commit), unlike `rev-parse --abbrev-ref HEAD`, which exits 128 there and used
    # to wipe the whole git segment exactly when the "new repo" signal is most useful.
    $revParts = git rev-parse --show-toplevel --git-dir --git-common-dir 2>$null
    if ($LASTEXITCODE -eq 0 -and $revParts) {
        $revLines     = @($revParts)
        $topLevel     = $revLines[0]
        $gitDir       = if ($revLines.Count -gt 1) { $revLines[1] } else { $null }
        $gitCommonDir = if ($revLines.Count -gt 2) { $revLines[2] } else { $null }
    } else {
        $revParts = git rev-parse --git-dir --git-common-dir 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $revParts) { return $null }
        $revLines     = @($revParts)
        $topLevel     = $null
        $gitDir       = $revLines[0]
        $gitCommonDir = if ($revLines.Count -gt 1) { $revLines[1] } else { $null }
    }

    # Branch name. `branch --show-current` prints the branch even on an unborn
    # branch (empty in detached HEAD), where `rev-parse --abbrev-ref HEAD` fails.
    $branch = git branch --show-current 2>$null
    if ($LASTEXITCODE -ne 0) { $branch = $null }

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

            # Conflicts (unmerged). The unmerged XY pairs are exactly DD, AU, UD,
            # UA, DU, AA, UU — every pair where at least one side is U, plus AA/DD.
            # The old `$idx -in U,A,D -and $wt -in U,A,D` mis-flagged AD (staged add,
            # then deleted in the worktree) as a conflict; match the real set instead.
            $xy = "$idx$wt"
            if ($xy -in 'DD','AU','UD','UA','DU','AA','UU') { $info.Conflicts++; continue }

            # Staged
            switch ($idx) {
                'M' { $info.Staged++ }
                'A' { $info.Staged++ }
                'D' { $info.Staged++ }
                'C' { $info.Staged++ }   # copied (index copy-detection)
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
        # psmux CWD tracking (OSC 7) — psmux updates pane_current_path from OSC 7, not OSC 9;9,
        # so new panes open in the focused pane's directory. [uri] renders the Windows path as a
        # file:// URL (spaces → %20). Harmless in Windows Terminal, which ignores OSC 7.
        $null = $out.Append("$($c.ESC)]7;$(([uri]$loc.ProviderPath).AbsoluteUri)$($c.ESC)\")

        # Record the directory in zoxide. zoxide is initialised with --hook none
        # (see profile), so it doesn't wrap the prompt — that wrapper detaches on
        # `. $PROFILE` reloads and silently stops recording. The prompt records
        # instead, mirroring zoxide's own __zoxide_hook: dedup on oldpwd so a
        # process spawns only when the directory changed, and the LASTEXITCODE
        # restore below undoes the exit code `zoxide add` leaves behind. Guarded on
        # __zoxide_pwd so it no-ops until Phase 2a initialises zoxide.
        if ($null -ne $function:__zoxide_pwd) {
            $zoxidePwd = __zoxide_pwd
            if ($zoxidePwd -ne $global:__zoxide_oldpwd) {
                if ($null -ne $zoxidePwd) { zoxide add '--' $zoxidePwd }
                $global:__zoxide_oldpwd = $zoxidePwd
            }
        }
    }

    # --- Line 1: user path git az ---

    # Cursor to column 0 — hardens the prompt against a dirty cursor left mid-row
    # by fzf's Windows renderer on abort (DISABLE_NEWLINE_AUTO_RETURN stuck), so
    # the prompt renders at the left margin. No-op when the cursor is already there.
    $null = $out.Append("$($c.ESC)[G")

    # Username
    if ($c.ShowUsername) {
        $null = $out.Append("$($c.Blue)$([Environment]::UserName)$($c.Reset) ")
    }

    # VCS (computed before the path so the path can anchor at the repo root).
    # jj takes precedence: in a colocated repo git would show a detached HEAD,
    # so when a jj repo is detected we skip git entirely.
    # Only probe VCS on a FileSystem provider (matching the CWD-tracking gate above):
    # under HKCU:/Cert:/Env: the jj/git helpers would spawn against the last synced
    # Win32 CWD and render stale repo info from wherever the shell last was.
    $isFileSystem = $loc.Provider.Name -eq 'FileSystem'
    $jj  = if ($isFileSystem -and $c.ShowJj) { Get-JjPromptInfo } else { $null }
    $git = if ($isFileSystem -and -not $jj) { Get-GitPromptInfo } else { $null }

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
        # CR+LF+clear-to-EOL — hardens against a dirty console left by fzf's Windows
        # renderer (newline-auto-return stuck) so each line starts at column 0. No-op
        # when the cursor is already there.
        $null = $out.Append("`r`n$($c.ESC)[K")
        $null = $out.Append($contextLine.ToString())
    }

    # --- Final line: duration status promptchar ---
    # CR+LF+clear-to-EOL — see the note above; keeps the command line at column 0
    # even when fzf leaves the console with newline-auto-return disabled.
    $null = $out.Append("`r`n$($c.ESC)[K")

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
            $timeStr = "$($ms.ToString('0'))ms"
            $timeColor = $c.Yellow
        } else {
            # '0' not '#': the '#' custom format renders sub-0.5ms as an EMPTY string
            # (e.g. 0.4 -> ''), yielding a blank "[ms]" segment; '0' always emits a digit.
            $timeStr = "$($ms.ToString('0'))ms"
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

# --- Az context init is deferred to Phase 2a (Initialize-DeferredProfile) ---
# Initialize-AzTimer is NOT called at profile load — runspace.Open() + eventing
# cost ~115ms cold. The main profile calls it on first idle to keep startup fast.
