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
    MaxPathLength   = 30
    MaxBranchLength = 35
    ShowWorktree    = $true
    ShowUsername     = $true
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
    Uses 3 git processes total: rev-parse (combined), rev-list, status.
    #>

    # Single rev-parse call: branch, git-dir, git-common-dir
    # Fails entirely if not in a repo, so this doubles as the gate check
    $revParts = git rev-parse --abbrev-ref HEAD --git-dir --git-common-dir 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $revParts) { return $null }

    # rev-parse returns one value per line
    $revLines = @($revParts)
    $branch      = $revLines[0]
    $gitDir      = if ($revLines.Count -gt 1) { $revLines[1] } else { $null }
    $gitCommonDir = if ($revLines.Count -gt 2) { $revLines[2] } else { $null }

    $info = @{
        Branch     = $branch
        IsWorktree = $false
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

# --- Path shortening --------------------------------------------------------
function Get-ShortenedPath {
    param([int]$MaxLength = 30)

    $path = $PWD.Path
    if ($path.StartsWith($HOME)) {
        $path = '~' + $path.Substring($HOME.Length)
    }

    if ($path.Length -le $MaxLength) { return $path }

    $sep = [IO.Path]::DirectorySeparatorChar
    $parts = $path.Split($sep)
    if ($parts.Count -le 3) {
        return $path.Substring(0, $MaxLength - 3) + '...'
    }

    # Keep first segment, abbreviate middle to initials, keep last
    $first = $parts[0]
    $last  = $parts[-1]
    $middle = ($parts[1..($parts.Count - 2)] | ForEach-Object { $_[0] }) -join $sep
    $shortened = "${first}${sep}${middle}${sep}${last}"

    if ($shortened.Length -gt $MaxLength) {
        $available = $MaxLength - $first.Length - $middle.Length - $sep.Length * 2 - 3
        if ($available -gt 0) {
            $last = $last.Substring(0, [Math]::Min($last.Length, $available)) + '...'
        }
        $shortened = "${first}${sep}${middle}${sep}${last}"
    }

    return $shortened
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

    # --- Windows Terminal CWD tracking (OSC 9;9) ---
    $loc = Get-Location
    if ($loc.Provider.Name -eq 'FileSystem') {
        $null = $out.Append("$($c.ESC)]9;9;`"$($loc.ProviderPath)`"$($c.ESC)\")
    }

    # --- Line 1: user path git az ---

    # Username
    if ($c.ShowUsername) {
        $null = $out.Append("$($c.Blue)$([Environment]::UserName)$($c.Reset) ")
    }

    # Path
    $shortPath = Get-ShortenedPath -MaxLength $c.MaxPathLength
    $null = $out.Append("in $($c.Green)$shortPath$($c.Reset) ")

    # Git
    $git = Get-GitPromptInfo
    if ($git -and $git.Branch) {
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
