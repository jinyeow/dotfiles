# gist:4f51b2f23ae8b90e160877e8a8f29bb5
#Requires -Version 7
#Requires -Module @{ ModuleName = 'PSReadLine'; ModuleVersion = '2.2.0' }

using module PSReadLine

# === VARIABLES ===
$installChocolatey = $false

# === TROUBLESHOOT STARTUP ===
# Set-PSDebug -Trace 1
# Install-Module PSProfiler
# Import-Module PSProfiler
# Measure-Script -Top 3 $profile

# Register-EngineEvent -SourceIdentifier PowerShell.Exiting -SupportEvent -Action {
#     Get-History | Export-Clixml $HOME\history.clixml
# }

# Initial GitHub.com connectivity check with 1 second timeout
$gitHubJob = Start-Job -ScriptBlock {
    $global:canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1
}
Register-ObjectEvent `
    -SourceIdentifier ($gitHubJob.InstanceId.Guid) `
    -InputObject $gitHubJob `
    -EventName StateChanged `
    -Action {
    if ($EventArgs.JobStateInfo.State -eq 'Completed') {
        Remove-Job -Job $sender
        Unregister-Event -SourceIdentifier $sender.InstanceId.Guid
    }
} > $null

# === PSReadLine ===
if (Get-Module -ListAvailable -Name 'PsReadLine' -ErrorAction SilentlyContinue) {
    if ((Get-Module PSReadLine).Version -lt 2.2) {
        Write-Error 'Profile requires PSReadLine 2.2+' -ErrorAction Stop
    }

    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -ShowToolTips

    Set-PSReadLineOption -Colors @{
        Command = 'Yellow'
        Parameter = 'Green'
        String = 'DarkCyan'
        InlinePrediction = 'DarkGray'
    }

    function OnViModeChange {
        if ($args[0] -eq 'Command') {
            # Set the cursor to a blinking block
            Write-Host -NoNewline "`e[1 q"
        } else {
            # Set the cursor to a blinking line
            Write-Host -NoNewline "`e[5 q"
        }
    }
    $PSReadLineOptions = @{
        EditMode                      = 'Vi'
        HistoryNoDuplicates           = $true
        HistorySearchCursorMovesToEnd = $true
        HistorySaveStyle              = 'SaveIncrementally'
        ViModeIndicator               = 'Script'
        ViModeChangeHandler           = $Function:OnViModeChange
    }
    Set-PSReadLineOption @PSReadLineOptions

    Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory
    Set-PSReadLineKeyHandler -Key Ctrl+Spacebar -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Tab -Function Complete

    Set-PSReadLineKeyHandler -Chord Ctrl+Oem4 -Function ViCommandMode # NOTE: see https://github.com/PowerShell/PSReadLine/issues/906#issuecomment-916847040
    Set-PSReadLineKeyHandler -Chord Shift+Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord Ctrl+b -Function BackwardChar
    Set-PSReadLineKeyHandler -Chord Ctrl+f -Function ForwardChar
    Set-PSReadLineKeyHandler -Chord Ctrl+p -Function PreviousHistory
    Set-PSReadLineKeyHandler -Chord Ctrl+n -Function NextHistory
    Set-PSReadLineKeyHandler -Chord Ctrl+a -Function BeginningOfLine
    Set-PSReadLineKeyHandler -Chord Ctrl+e -Function EndOfLine
    Set-PSReadLineKeyHandler -Chord Ctrl+w -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord Ctrl+u -Function BackwardDeleteLine
}

# === PROMPT ===
if (-not $global:AzContextPromptState) {
    $global:AzContextPromptState = @{
        Hash            = $null
        Info            = $null
        Job             = $null
        LastRefresh     = [datetime]::MinValue
        RefreshInterval = [timespan]::FromSeconds(60)
    }
}
if (-not $global:AzCliAccountPromptState) {
    $global:AzCliAccountPromptState = @{
        Hash            = $null
        Info            = $null
        Job             = $null
        LastRefresh     = [datetime]::MinValue
        RefreshInterval = [timespan]::FromSeconds(60)
    }
}

function Get-CurrentAzContextHash {
    try {
        $context = Get-AzContext
        if ($context) {
            return "$($context.Account)|$($context.Subscription.Id)"
        }
    } catch {}
    return 'no-context'
}

function Get-CurrentAzCliAccountHash {
    try {
        $context = (az account show | ConvertFrom-Json -Depth 32)
        if ($context) {
            return "$($context.user.name)|$($context.id)"
        }
    } catch {}
    return 'no-context'
}

function Start-AzContextJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Type
    )

    $scriptBlock = {
        try {
            $context = Get-AzContext
            if ($context) {
                @{
                    Text = "$($context.Account) ($($context.Subscription.Name))"
                    Hash = "$($context.Account)|$($context.Subscription.Id)"
                }
            } else {
                @{
                    Text = $null
                    Hash = 'no-context'
                }
            }
        } catch {
            @{
                Text = $null
                Hash = 'error'
            }
        }
    }
    $global:AzContextPromptState.Job = Start-Job -ScriptBlock $scriptBlock
    Register-ObjectEvent `
        -SourceIdentifier ($global:AzContextPromptState.Job.InstanceId.Guid) `
        -InputObject $global:AzContextPromptState.Job `
        -EventName StateChanged `
        -Action {
        if ($EventArgs.JobStateInfo.State -eq 'Completed') {
            $result = Receive-Job -Job $sender
            $global:AzContextPromptState.Info = $result.Text
            $global:AzContextPromptState.Hash = $result.Hash
            $global:AzContextPromptState.LastRefresh = Get-Date
            Remove-Job -Job $sender
            Unregister-Event -SourceIdentifier $sender.InstanceId.Guid
        }
    } > $null
}

function Start-AzCliAccountJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Type
    )

    $scriptBlock = {
        try {
            $context = (az account show | ConvertFrom-Json -Depth 32)
            if ($context) {
                @{
                    Text = "$($context.user.name) ($($context.name))"
                    Hash = "$($context.user.name)|$($context.id)"
                }
            } else {
                @{
                    Text = $null
                    Hash = 'no-context'
                }
            }
        } catch {
            @{
                Text = $null
                Hash = 'error'
            }
        }
    }
    $global:AzCliAccountPromptState.Job = Start-Job -ScriptBlock $scriptBlock
    Register-ObjectEvent `
        -SourceIdentifier ($global:AzCliAccountPromptState.Job.InstanceId.Guid) `
        -InputObject $global:AzCliAccountPromptState.Job `
        -EventName StateChanged `
        -Action {
        if ($EventArgs.JobStateInfo.State -eq 'Completed') {
            $result = Receive-Job -Job $sender
            $global:AzCliAccountPromptState.Info = $result.Text
            $global:AzCliAccountPromptState.Hash = $result.Hash
            $global:AzCliAccountPromptState.LastRefresh = Get-Date
            Remove-Job -Job $sender
            Unregister-Event -SourceIdentifier $sender.InstanceId.Guid
        }
    } > $null
}

function Confirm-RefreshAzContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Type
    )

    $now = Get-Date
    $expired = ($now - $global:AzContextPromptState.LastRefresh) -gt $global:AzContextPromptState.RefreshInterval
    $currentHash = Get-CurrentAzContextHash
    $changed = $currentHash -ne $global:AzContextPromptState.Hash
    return $expired -or $changed
}

function Confirm-RefreshAzCliAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Type
    )

    $now = Get-Date
    $expired = ($now - $global:AzCliAccountPromptState.LastRefresh) -gt $global:AzCliAccountPromptState.RefreshInterval
    $currentHash = Get-CurrentAzCliAccountHash
    $changed = $currentHash -ne $global:AzCliAccountPromptState.Hash
    return $expired -or $changed
}

function Set-PromptGitStatus {
    if ($null -eq (Get-Command -Name git -ErrorAction SilentlyContinue)) {
        return ''
    }
    $STATUS = "$(git status)"
    $output = ''
    if ([string]::IsNullOrEmpty($STATUS)) {
        $output += '-'
        return
    } else {
        $output += '['
    }

    if ($STATUS | Select-String -Pattern 'up to date') { $output += '=' }
    if ($STATUS | Select-String -Pattern 'branch is ahead') { $output += '>' }
    if ($STATUS | Select-String -Pattern 'branch is behind') { $output += '<' }
    if ($STATUS | Select-String -Pattern 'renamed:') { $output += 'R' }
    if ($STATUS | Select-String -Pattern 'new file:') { $output += '+' }
    if ($STATUS | Select-String -Pattern 'Untracked files:') { $output += '?' }
    if ($STATUS | Select-String -Pattern 'modified:') { $output += '*' }
    if ($STATUS | Select-String -Pattern 'deleted:') { $output += '-' }

    if (-not ([string]::IsNullOrEmpty($STATUS))) {
        $output += ']'
    }
    $output
}

function Set-PromptDirectoryPathShort {
    # truncate the current location if too long
    $currentDirectory = $executionContext.SessionState.Path.CurrentLocation.Path
    $consoleWidth = [Console]::WindowWidth
    $maxPath = [int]($consoleWidth / 3)
    if ($currentDirectory.Length -gt $maxPath) {
        $parents = $currentDirectory -Split '\\'
        $drive = $parents[0]
        $leaf = $(Split-Path -Path $currentDirectory -Leaf)
        $parent = "$($drive)\"
        # Remove the drive and the current directory from list of parent directories
        $parents = $($parents | Select-Object -Skip 1 | Select-Object -SkipLast 1)
        foreach ($p in $parents) {
            $parent += "$($p[0])\"
        }
        $currentDirectory = "${parent}${leaf}$($color.Reset)"
        #$currentDirectory = "`u{2026}" + $currentDirectory.SubString($currentDirectory.Length - $maxPath) + "$($color.Reset)"
    }
    "$($color.Green)${currentDirectory}$($color.Reset)"
}

function prompt {
    $currentLastExitCode = $LASTEXITCODE
    $lastCommandSuccess = [boolean]($LASTEXITCODE -eq 0)

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

    # Set color of PS based on success of last execution
    if ($lastCommandSuccess) {
        $lastExit = $color.Green
    } else {
        $lastExit = $color.Red
    }

    # get the execution time of the last command
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
    }

    # get git branch information if in a git folder or subfolder
    $gitBranch = ''
    $path = Get-Location
    while ($path -ne '') {
        if (Test-Path ([System.IO.Path]::Combine($path, '.git'))) {
            # need to do this so the stderr doesn't show up in $error
            $ErrorActionPreferenceOld = $ErrorActionPreference
            $ErrorActionPreference = 'Ignore'
            $branch = $(git rev-parse --abbrev-ref --symbolic-full-name '@{u}') -replace 'origin/', ''
            $ErrorActionPreference = $ErrorActionPreferenceOld

            # handle case where branch is local
            if ($lastexitcode -ne 0 -or $null -eq $branch) {
                $branch = git rev-parse --abbrev-ref HEAD
            }

            $branchStatus = "$(Set-PromptGitStatus)"
            if ($branch.Length -gt 30) {
                if ($branch -match '^[a-zA-Z]+/[0-9]+-.*$') {
                    $branch = $branch.split('-')[0]
                } elseif ($branch -match '^[a-zA-Z]+/\w+/.*$') {
                    $splits = $branch.split('/')[0]
                    $branch = "$($splits[0])/$($splits[1])"
                } else {
                    $branch = $branch.SubString(0, 20)
                }
            }
            $gitBranch = " $($color.Reset)on $($color.Yellow)$branch $($color.Red)$branchStatus$($color.Reset)"
            break
        }
        $path = Split-Path -Path $path -Parent
    }

    $currentDirectory = Set-PromptDirectoryPathShort
    $currentTime = "$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')"
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
    $promptChar = if ($principal.IsInRole('Administrators')) {
        '#'
    } else {
        '>'
    }

    $loc = $executionContext.SessionState.Path.CurrentLocation
    $out = ''
    if ($loc.Provider.Name -eq 'FileSystem') {
        $out += "$([char]27)]9;9;`"$($loc.ProviderPath)`"$([char]27)\"
    }

    if (-not $global:AzContextPromptState.Job -or (Confirm-RefreshAzContext -Type 'AzContext')) {
        Start-AzContextJob -Type 'AzContext'
    }
    $azContext = if ($global:AzContextPromptState.Info) { "$($color.Blue)$($global:AzContextPromptState.Info)$($color.Reset)`n" } else { '' }

    # if (-not $global:AzCliAccountPromptState.Job -or (Confirm-RefreshAzCliAccount -Type 'azcli')) {
    #     Start-AzCliAccountJob -Type 'azcli'
    # }
    $azCliContext = if ($global:AzCliAccountPromptState.Info) { "$($color.Blue)$($global:AzCliAccountPromptState.Info)$($color.Reset)`n" } else { '' }

    # Clean up background jobs
    Get-Job | Where-Object { $_.JobStateInfo.State -eq 'Stopped' } | Remove-Job -Force

    "${out}${azContext}${azCliContext}${lastCmdTime}${currentDirectory}${gitBranch}${devBuild}`n${currentTime}${lastExit} $($promptChar * ($nestedPromptLevel + 1))$($color.Reset) "
    $global:LASTEXITCODE = $currentLastExitCode
}

# === MODULES ===
$modules = @(
    # 'Az.Tools.Predictor' ## Causing issues with tab completion?
    'posh-git'
    'PsFzf'
    'PSReadLine'
)
$moduleScriptBlock = {
    param(
        [string]$module
    )

    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Warning "$module module not found. Attempting to install..."
        try {
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Host "$module installed successfully."
        } catch {
            Write-Error "Failed to install $module. Please install manually:"
            Write-Host "Install-Module $module -Scope CurrentUser -Force -AllowClobber"
        }
    } else {
        try {
            Update-Module -Name $module -Scope CurrentUser -Force -AllowClobber
            Write-Host "$module updated successfully."
        } catch {
            Write-Error "Failed to update $module. Please update manually:"
            Write-Host "Update-Module -Name $module -Scope CurrentUser -Force -AllowClobber"
        }
    }
}

foreach ($module in $modules) {
    $job = Start-Job `
        -ScriptBlock $moduleScriptBlock `
        -ArgumentList "$module" `
        -Name "$($module)_Job"
    Register-ObjectEvent `
        -SourceIdentifier $job.InstanceId.Guid `
        -InputObject $job `
        -EventName StateChanged `
        -MessageData $module `
        -Action {
        if ($EventArgs.JobStateInfo.State -eq 'Completed' -or $EventArgs.JobStateInfo.State -eq 'Stopped') {
            Remove-Job -Job $sender
            Unregister-Event -SourceIdentifier $sender.InstanceId.Guid
            try {
                Import-Module $Event.MessageData -Scope Global -Force -ErrorAction Stop
            } catch {
                Write-Warning "Could not import module: $($Event.MessageData). Some functions may not work as expected."
            }
        }
    } > $null
}

# === EXTERNAL TOOLS INSTALLS ===
if ($null -eq $(Get-Command -Name 'scoop' -ErrorAction SilentlyContinue)) {
    Write-Host '-- Command [scoop] not installed. Installing now.'
    $job = Start-Job `
        -ScriptBlock {
        $executionPolicy = Get-ExecutionPolicy
        if ($executionPolicy -ne 'RemoteSigned') {
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
        }
        Invoke-RestMethod get.scoop.sh | Invoke-Expression
        Set-ExecutionPolicy "$executionPolicy" -Scope CurrentUser
    } `
        -Name 'Install_Scoop_Job'
    Register-ObjectEvent `
        -SourceIdentifier $job.InstanceId.Guid `
        -InputObject $job `
        -EventName StateChanged `
        -Action {
        if ($EventArgs.JobStateInfo.State -eq 'Completed' -or $EventArgs.JobStateInfo.State -eq 'Stopped') {
            Remove-Job -Job $sender
            Unregister-Event -SourceIdentifier $sender.InstanceId.Guid
        }
    } > $null
}

if ($installChocolatey -and $null -eq $(Get-Command -Name 'choco' -ErrorAction SilentlyContinue)) {
    Write-Host '-- Command [choco] not installed. Installing now.'
    Start-Job -ScriptBlock {
        $executionPolicy = Get-ExecutionPolicy
        if ($executionPolicy -ne 'Bypass') {
            Set-ExecutionPolicy Bypass -Scope Process -Force
        }
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Set-ExecutionPolicy "$executionPolicy" -Scope CurrentUser
    } -Name 'Install_Choco_Job' > $null
}

# === PSFzf ===
if (Get-Module -ListAvailable -Name 'PsFzf' -ErrorAction SilentlyContinue) {
    # Replace standard TAB completion
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }

    Set-PsFzfOption `
        -PSReadlineChordProvider 'Ctrl+t' `
        -PSReadlineChordReverseHistory 'Ctrl+r'
    # NOTE: taken from - https://gist.github.com/SteveL-MSFT/a208d2bd924691bae7ec7904cab0bd8e

    # example command - use $Location with a different command:
    $commandOverride = [ScriptBlock] { param($Location) Write-Host $Location }
    # pass your override to PSFzf:
    Set-PsFzfOption `
        -AltCCommand $commandOverride `
        -EnableAliasFuzzyEdit `
        -EnableAliasFuzzyGitStatus `
        -EnableAliasFuzzyHistory `
        -EnableAliasFuzzyKillProcess `
        -EnableAliasFuzzySetLocation
}

# === azcli Tab Completion ===
if ($null -ne (Get-Command -Name az -ErrorAction SilentlyContinue)) {
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

# === STARTUP ===

# === ALIASES ===
if ($PSVersionTable.PSVersion.Major -eq 5) {
    Remove-Item alias:wget
    Remove-Item alias:curl
}
Set-Alias -Name g -Value git

# === FUNCTIONS ===
function gst {
    git status
}

<#
    .SYNOPSIS
    Starts a new PowerShell session with elevated rights. Alias: su
#>
function Start-AdminSession {
    Start-Process wt -Verb RunAs
}
Set-Alias -Name su -Value Start-AdminSession

# == Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    $module = "$ChocolateyProfile"
    $job = Start-Job `
        -ScriptBlock $moduleScriptBlock `
        -ArgumentList "$module" `
        -Name "$($module)_Job"
    Register-ObjectEvent `
        -SourceIdentifier $job.InstanceId.Guid `
        -InputObject $job `
        -EventName StateChanged `
        -MessageData $module `
        -Action {
        if ($EventArgs.JobStateInfo.State -eq 'Completed' -or $EventArgs.JobStateInfo.State -eq 'Stopped') {
            Remove-Job -Job $sender
            Unregister-Event -SourceIdentifier $sender.InstanceId.Guid
            try {
                Import-Module $Event.MessageData -Scope Global -Force -ErrorAction Stop
            } catch {
                Write-Warning "Could not import module: $($Event.MessageData). Some functions may not work as expected."
            }
        }
    } > $null
}

function which ($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

# === zoxide ===
# https://github.com/ajeetdsouza/zoxide
# As per documentation, set at the end of the PROFILE
if ($null -ne (Get-Command -Name zoxide -ErrorAction SilentlyContinue)) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
