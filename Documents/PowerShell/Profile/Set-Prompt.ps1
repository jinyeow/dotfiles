# Advanced PowerShell Prompt Configuration
# Add this to your PowerShell profile ($PROFILE)

# Configuration
$global:PromptConfig = @{
    ShowUsername = $true
    MaxPathLength = 30
    MaxBranchLength = 35
    ShowWorktree = $true
    TimeThresholds = @{
        Fast = 1    # Green if under 1 second
        Medium = 5  # Yellow if under 5 seconds
                    # Red if over 5 seconds
    }
    AsyncTimeout = 100  # Milliseconds to wait for async results
}

# Global cache for async results
$global:PromptCache = @{
    GitStatus = $null
    AzureStatus = $null
    LastPath = $null
    GitRunspace = $null
    AzureRunspace = $null
}

# Track command execution time
$global:CommandStartTime = $null

# Pre-command: Record start time
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param($commandName, $eventArgs)
}

# Use PowerShell's built-in prompt timing
$null = [System.Diagnostics.Stopwatch]::StartNew()

function Start-AsyncGitStatus {
    param([string]$Path)

    # Clean up previous runspace if it exists
    if ($global:PromptCache.GitRunspace) {
        try {
            $global:PromptCache.GitRunspace.PowerShell.Dispose()
            $global:PromptCache.GitRunspace.Runspace.Dispose()
        } catch {}
    }

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.Path.SetLocation($Path)

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    $null = $ps.AddScript({
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }

        $gitDir = git rev-parse --git-dir 2>$null
        if (-not $gitDir) { return $null }

        $status = @{
            Branch = $null
            Ahead = 0
            Behind = 0
            HasChanges = $false
            IsWorktree = $false
            WorktreePath = $null
        }

        # Get branch name
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        $status.Branch = $branch

        # Check if it's a worktree
        $gitCommonDir = git rev-parse --git-common-dir 2>$null
        if ($gitDir -ne $gitCommonDir) {
            $status.IsWorktree = $true
            $status.WorktreePath = Split-Path (git rev-parse --show-toplevel 2>$null) -Leaf
        }

        # Get ahead/behind counts
        $aheadBehind = git rev-list --left-right --count '@{upstream}...HEAD' 2>$null
        if ($aheadBehind -match '(?<behind>\d+)\s+(?<ahead>\d+)') {
            $status.Behind = [int]$matches.behind
            $status.Ahead = [int]$matches.ahead
        }

        # Check for changes
        $statusOutput = git status --porcelain 2>$null
        $status.HasChanges = $statusOutput.Length -gt 0

        if ($statusOutput) {
            $status.HasChanges = $true
            foreach ($line in $statusOutput) {
                if ($line.Length -lt 2) { continue }
                $index = $line[0]
                $workTree = $line[1]
                # Check for conflicts (unmerged paths)
                if ($index -in 'U','A','D' -and $workTree -in 'U','A','D') {
                    $status.Conflicts++
                    continue
                }
                # Index (staged) status
                switch ($index) {
                    'M' { $status.Staged++ }
                    'A' { $status.Staged++ }
                    'D' { $status.Staged++ }
                    'R' { $status.Renamed++ }
                    'C' { $status.Copied++ }
                }
                # Working tree status
                switch ($workTree) {
                    'M' { $status.Modified++ }
                    'D' { $status.Deleted++ }
                }
                # Untracked files
                if ($index -eq '?' -and $workTree -eq '?') {
                    $status.Untracked++
                }
            }
        }
        return $status
    })

    $handle = $ps.BeginInvoke()

    $global:PromptCache.GitRunspace = @{
        PowerShell = $ps
        Runspace = $runspace
        Handle = $handle
    }
}

function Start-AsyncAzureStatus {
    # Clean up previous runspace if it exists
    if ($global:PromptCache.AzureRunspace) {
        try {
            $global:PromptCache.AzureRunspace.PowerShell.Dispose()
            $global:PromptCache.AzureRunspace.Runspace.Dispose()
        } catch {}
    }

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    $null = $ps.AddScript({
        $azStatus = @{
            PowerShellAccount = $null
            PowerShellSubscription = $null
            CLIAccount = $null
            CLISubscription = $null
        }

        # Check Azure PowerShell
        if (Get-Command Get-AzContext -ErrorAction SilentlyContinue) {
            try {
                $context = Get-AzContext -ErrorAction SilentlyContinue
                if ($context) {
                    $azStatus.PowerShellAccount = $context.Account.Id
                    $azStatus.PowerShellSubscription = $context.Subscription.Name
                }
            } catch {}
        }

        # Check Azure CLI
        if (Get-Command az -ErrorAction SilentlyContinue) {
            try {
                $cliAccount = az account show --query "{account:user.name, subscription:name}" -o json 2>$null | ConvertFrom-Json
                if ($cliAccount) {
                    $azStatus.CLIAccount = $cliAccount.account
                    $azStatus.CLISubscription = $cliAccount.subscription
                }
            } catch {}
        }

        return $azStatus
    })

    $handle = $ps.BeginInvoke()

    $global:PromptCache.AzureRunspace = @{
        PowerShell = $ps
        Runspace = $runspace
        Handle = $handle
    }
}

function Get-AsyncResult {
    param(
        [hashtable]$RunspaceInfo,
        [int]$TimeoutMs
    )

    if (-not $RunspaceInfo) { return $null }

    try {
        $completed = $RunspaceInfo.Handle.AsyncWaitHandle.WaitOne($TimeoutMs)

        if ($completed) {
            $result = $RunspaceInfo.PowerShell.EndInvoke($RunspaceInfo.Handle)
            $RunspaceInfo.PowerShell.Dispose()
            $RunspaceInfo.Runspace.Dispose()
            return $result
        } else {
            # Still running, return null and let it continue
            return $null
        }
    } catch {
        # Error occurred, clean up
        try {
            $RunspaceInfo.PowerShell.Dispose()
            $RunspaceInfo.Runspace.Dispose()
        } catch {}
        return $null
    }
}

function Get-ShortenedPath {
    param([int]$MaxLength = 50)

    $path = $PWD.Path

    # Replace home directory with ~
    if ($path.StartsWith($HOME)) {
        $path = $path.Replace($HOME, '~')
    }

    if ($path.Length -le $MaxLength) {
        return $path
    }

    # Shorten by keeping first and last parts
    $parts = $path.Split([IO.Path]::DirectorySeparatorChar)
    if ($parts.Count -le 3) {
        return $path.Substring(0, $MaxLength - 3) + '...'
    }

    $first = $parts[0]
    $last = $parts[-1]
    $parents = $($parts |
        Select-Object -Skip 1 |
        Select-Object -SkipLast 1)
    $middle = ''
    foreach ($parent in $parents) {
        $middle += "$($parent[0])$([IO.Path]::DirectorySeparatorChar)"
    }

    $shortened = "$first\$middle$last"

    # If still too long, truncate the last part
    if ($shortened.Length -gt $MaxLength) {
        $maxLast = $MaxLength - $first.Length - $middle.Length - 5
        $last = $last.Substring(0, [Math]::Max(1, $maxLast)) + '...'
        $shortened = "$first\$middle$last"
    }

    return $shortened
}

function Get-ShortenedBranch {
    param([string]$Branch, [int]$MaxLength = 30)

    if ($Branch.Length -le $MaxLength) {
        return $Branch
    }

    # Keep beginning and end
    $keepLength = [Math]::Floor($MaxLength / 2) - 2
    return $Branch.Substring(0, $keepLength) + '...' + $Branch.Substring($Branch.Length - $keepLength)
}

function prompt {
    $lastSuccess = $?
    $lastExit = $LASTEXITCODE

    $color = @{
        Reset         = "`e[0m"
        Blue          = "`e[34;1m"
        Red           = "`e[31;1m"
        Green         = "`e[32;1m"
        Yellow        = "`e[33;1m"
        Grey          = "`e[37;0m"
        White         = "`e[37;1m"
        Invert        = "`e[7m"
        RedBackground = "`e[41m"
    }

    # Calculate execution time
    $executionTime = $null
    if ($global:PromptStopwatch) {
        $executionTime = $global:PromptStopwatch.Elapsed.TotalSeconds
    }
    $global:PromptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Check if path changed or if we don't have cached results
    $currentPath = $PWD.Path
    $pathChanged = $currentPath -ne $global:PromptCache.LastPath

    if ($pathChanged) {
        $global:PromptCache.LastPath = $currentPath
        # Start new async operations
    }

    if ($executionTime -gt 5) {
        Start-AsyncGitStatus -Path $currentPath
        Start-AsyncAzureStatus
    }

    # Try to get results from async operations
    $gitStatus = Get-AsyncResult -RunspaceInfo $global:PromptCache.GitRunspace -TimeoutMs $PromptConfig.AsyncTimeout
    if ($gitStatus) {
        $global:PromptCache.GitStatus = $gitStatus
        $global:PromptCache.GitRunspace = $null
    } else {
        # Use cached result if async not complete
        $gitStatus = $global:PromptCache.GitStatus
    }

    $azStatus = Get-AsyncResult -RunspaceInfo $global:PromptCache.AzureRunspace -TimeoutMs $PromptConfig.AsyncTimeout
    if ($azStatus) {
        $global:PromptCache.AzureStatus = $azStatus
        $global:PromptCache.AzureRunspace = $null
    } else {
        # Use cached result if async not complete
        $azStatus = $global:PromptCache.AzureStatus
    }

    # If we still don't have results and no async operation is running, start new ones
    if (-not $gitStatus -and -not $global:PromptCache.GitRunspace) {
        Start-AsyncGitStatus -Path $currentPath
    }
    if (-not $azStatus -and -not $global:PromptCache.AzureRunspace) {
        Start-AsyncAzureStatus
    }

    # Build prompt
    $prompt = ""

    # Windows Terminal directory tracking (must be first)
    # $prompt += "`e]9;9;`"$($PWD.Path)`"`e\"
    $out = ''
    if ($loc.Provider.Name -eq 'FileSystem') {
        $out += "$([char]27)]9;9;`"$($loc.ProviderPath)`"$([char]27)\"
    }
    $prompt += "${out}"


    # Username
    if ($PromptConfig.ShowUsername) {
        $prompt += "$([char]27)[34m$([Environment]::UserName)$([char]27)[0m "
    }

    # Current path
    $shortPath = Get-ShortenedPath -MaxLength $PromptConfig.MaxPathLength
    $prompt += "in $([char]27)[32m$shortPath$([char]27)[0m "

    # Git information
    if ($gitStatus) {
        # Branch
        $shortBranch = Get-ShortenedBranch -Branch $gitStatus.Branch -MaxLength $PromptConfig.MaxBranchLength
        $branchColor = if ($gitStatus.HasChanges) { '31' } else { '33' }
        $prompt += "$([char]27)[${branchColor}m±$shortBranch$([char]27)[0m"

        # Upstream status (ahead/behind)
        if ($gitStatus.Ahead -gt 0 -and $gitStatus.Behind -gt 0) {
            $statusIndicators += "$([char]27)[93m↕$([char]27)[0m"  # Yellow for diverged
        } elseif ($gitStatus.Ahead -gt 0) {
            $statusIndicators += "$([char]27)[92m↑$($gitStatus.Ahead)$([char]27)[0m"
        } elseif ($gitStatus.Behind -gt 0) {
            $statusIndicators += "$([char]27)[91m↓$($gitStatus.Behind)$([char]27)[0m"
        } else {
            $statusIndicators += "$([char]27)[92m=$([char]27)[0m"  # Up to date
        }

        # File status indicators
        if ($gitStatus.Conflicts -gt 0) {
            $statusIndicators += "$([char]27)[91m!$($gitStatus.Conflicts)$([char]27)[0m"  # Conflicts
        }
        if ($gitStatus.Staged -gt 0) {
            $statusIndicators += "$([char]27)[92m+$($gitStatus.Staged)$([char]27)[0m"  # Staged (green)
        }
        if ($gitStatus.Modified -gt 0) {
            $statusIndicators += "$([char]27)[93m*$($gitStatus.Modified)$([char]27)[0m"  # Modified (yellow)
        }
        if ($gitStatus.Deleted -gt 0) {
            $statusIndicators += "$([char]27)[91m-$($gitStatus.Deleted)$([char]27)[0m"  # Deleted (red)
        }
        if ($gitStatus.Renamed -gt 0) {
            $statusIndicators += "$([char]27)[96mR$($gitStatus.Renamed)$([char]27)[0m"  # Renamed (cyan)
        }
        if ($gitStatus.Copied -gt 0) {
            $statusIndicators += "$([char]27)[96mC$($gitStatus.Copied)$([char]27)[0m"  # Copied (cyan)
        }
        if ($gitStatus.Untracked -gt 0) {
            $statusIndicators += "$([char]27)[95m?$($gitStatus.Untracked)$([char]27)[0m"  # Untracked (magenta)
        }

        if ($statusIndicators) {
            $prompt += " $statusIndicators"
        }
        # Worktree
        if ($PromptConfig.ShowWorktree -and $gitStatus.IsWorktree) {
            $prompt += " $([char]27)[95m[wt:$($gitStatus.WorktreePath)]$([char]27)[0m"
        }

        $prompt += " "
    }

    # Azure status
    if ($azStatus -and ($azStatus.PowerShellSubscription -or $azStatus.CLISubscription)) {
        $prompt += "`n$([char]27)[94m☁️ Az:$([char]27)[0m "

        if ($azStatus.PowerShellSubscription) {
            $prompt += "$([char]27)[36mPS:$($azStatus.PowerShellSubscription)$([char]27)[0m "
        }

        if ($azStatus.CLISubscription -and ($azStatus.CLISubscription -ne $azStatus.PowerShellSubscription)) {
            $prompt += "$([char]27)[36mCLI:$($azStatus.CLISubscription)$([char]27)[0m "
        }

        $prompt += ""
    }

    # New line for execution time and exit code
    $prompt += "`n"

    # Execution time
    if ($null -ne $executionTime) {
        $timeColor = if ($executionTime -lt $PromptConfig.TimeThresholds.Fast) {
            '92' # Green
        } elseif ($executionTime -lt $PromptConfig.TimeThresholds.Medium) {
            '93' # Yellow
        } else {
            '91' # Red
        }
        # $prompt += "$([char]27)[${timeColor}m⏱️ $($executionTime.ToString('0.00'))s$([char]27)[0m "
    }

    # Get the execution time of the last command
    $lastCmdTime = ''
    $lastCmd = Get-History -Count 1
    if ($null -ne $lastCmd) {
        $cmdTime = $lastCmd.Duration.TotalMilliseconds
        $units = 'ms'
        $timeColor = $color.Green
        if ($cmdTime -gt 250 -and $cmdTime -lt 1000) {
            $timeColor = $color.Yellow
        } elseif ($cmdTime -ge 1000) {
            $timeColor = $color.Red
            $units = 's'
            $cmdTime = $lastCmd.Duration.TotalSeconds
            if ($cmdTime -ge 60) {
                $units = 'm'
                $cmdTIme = $lastCmd.Duration.TotalMinutes
            }
        }
        $lastCmdTime = "$($color.Grey)[$timeColor$($cmdTime.ToString('#.##'))$units$($color.Grey)]$($color.Reset) "
        $prompt += "$lastCmdTime"
    }

    # Exit code
    if ($null -ne $lastExit -and $lastExit -ne 0) {
        $prompt += "$([char]27)[91m✗ `$?:$lastExit$([char]27)[0m "
    } elseif ($lastSuccess) {
        $prompt += "$([char]27)[92m✓$([char]27)[0m "
    } else {
        $prompt += "$([char]27)[91m✗$([char]27)[0m "
    }

    # Check if running in privileged mode or not
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    $promptCharacter = if ($principal.IsInRole('Administrators')) {
        '#'
    } else {
        '$'
        # '>'
        # '❯'
    }

    # Final prompt character multiplied by the nested level
    $prompt += "$([char]27)[97m$($promptCharacter * ($NestedPromptLevel + 1))$([char]27)[0m "

    # Reset LASTEXITCODE if it was 0
    if ($lastExit -eq 0) {
        $global:LASTEXITCODE = 0
    }

    return $prompt
}

# Initialize stopwatch
$global:PromptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "Advanced PowerShell prompt loaded!" -ForegroundColor Green
Write-Host "Configuration available in `$PromptConfig" -ForegroundColor Cyan

