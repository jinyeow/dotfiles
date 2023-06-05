# gist:4f51b2f23ae8b90e160877e8a8f29bb5
#Requires -Version 7

Import-Module posh-git

<#
	Install Scoop:
	> Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
	> irm get.scoop.sh | iex

	Install Chocolatey
	> Set-ExecutionPolicy Bypass -Scope Process -Force; \
		[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
		iex ((New-Object System.Net.WebClient).DownloadString(‘https://community.chocolatey.org/install.ps1'))
#>

function OnViModeChange {
    if ($args[0] -eq 'Command') {
        # Set the cursor to a blinking block
        Write-Host -NoNewline "`e[1 q"
    } else {
        # Set the cursor to a blinking line
        Write-Host -NoNewline "`e[5 q"
    }
}

# if ((Get-Module PSReadLine).Version -lt 2.2) {
# 	throw 'Profile requires PSReadLine 2.2+'
# }

Import-Module PSReadLine

$PSReadLineOptions = @{
    EditMode                      = 'Vi'
    HistoryNoDuplicates           = $true
    HistorySearchCursorMovesToEnd = $true
    HistorySaveStyle              = 'SaveIncrementally'
    PredictionSource              = 'History'
    PredictionViewStyle           = 'ListView'
    ViModeIndicator               = 'Script'
    ViModeChangeHandler           = $Function:OnViModeChange
}

Set-PSReadLineOption @PSReadLineOptions

Set-PSReadLineKeyHandler -Chord Shift+Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord Ctrl+b -Function BackwardChar
Set-PSReadLineKeyHandler -Chord Ctrl+f -Function ForwardChar
Set-PSReadLineKeyHandler -Chord Ctrl+p -Function PreviousHistory
Set-PSReadLineKeyHandler -Chord Ctrl+n -Function NextHistory
Set-PSReadLineKeyHandler -Chord Ctrl+Oem4 -Function ViCommandMode # NOTE: see https://github.com/PowerShell/PSReadLine/issues/906#issuecomment-916847040
Set-PSReadLineKeyHandler -Chord Ctrl+a -Function BeginningOfLine
Set-PSReadLineKeyHandler -Chord Ctrl+e -Function EndOfLine
Set-PSReadLineKeyHandler -Chord Ctrl+w -Function BackwardDeleteWord

Import-Module Az.Tools.Predictor
Set-PSReadLineOption -PredictionSource HistoryAndPlugin

# == zoxide ==
# For zoxide v0.8.0+
Invoke-Expression (& {
        $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
		(zoxide init --hook $hook powershell | Out-String)
    })

# # For older versions of zoxide
# Invoke-Expression (& {
# 		$hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
# 		(zoxide init --hook $hook powershell) -join "`n"
# 	})

# == PSFzf ==
#Remove-PSReadLineKeyHandler 'Ctrl+r'
#Remove-PSReadLineKeyHandler 'Ctrl+t'
Import-Module PSFzf

# replace standard tab completion
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
Set-Alias -Name frg -Value Invoke-PsFzfRipgrep
Set-PSReadLineKeyHandler -Chord 'alt+f' -ScriptBlock { Invoke-PsFzfRipgrep -SearchString '.' }

Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'

# NOTE: taken from - https://gist.github.com/SteveL-MSFT/a208d2bd924691bae7ec7904cab0bd8e
# == Prompt ==
function parse_git_dirty {
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

function dirtrim {
    # truncate the current location if too long
    $currentDirectory = $executionContext.SessionState.Path.CurrentLocation.Path
    $consoleWidth = [Console]::WindowWidth
    $maxPath = [int]($consoleWidth / 3)
    if ($currentDirectory.Length -gt $maxPath) {
        $separator = [IO.Path]::DirectorySeparatorChar
        $parents = $currentDirectory -Split "\${separator}"
        $drive = $parents[0]
        $leaf = $(Split-Path -Path $currentDirectory -Leaf)
        $parent = "$($drive)\"
        # Remove the drive and the current directory from list of parent directories
        $parents = $($parents | Select-Object -Skip 1 | Select-Object -SkipLast 1)
        foreach ($p in $parents) {
            $parent += "$($p[0])${separator}"
        }
        $currentDirectory = "${parent}${leaf}$($color.Reset)"
        #$currentDirectory = "`u{2026}" + $currentDirectory.SubString($currentDirectory.Length - $maxPath) + "$($color.Reset)"
    }
    "$($color.Green)${currentDirectory}"
}

function prompt {
    $currentLastExitCode = $LASTEXITCODE
    $lastSuccess = $?

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

    # set color of PS based on success of last execution
    if ($lastSuccess -eq $false) {
        $lastExit = $color.Red
    } else {
        $lastExit = $color.Green
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

            $branchColor = $color.Yellow
            $branchStatus = "$(parse_git_dirty)"

            $gitBranch = " $($color.Grey)on $branchColor$branch $($color.Red)$branchStatus$($color.Reset)"
            break
        }

        $path = Split-Path -Path $path -Parent
    }

    # check if running dev built pwsh
    $devBuild = ''
    if ($PSHOME.Contains('publish')) {
        $devBuild = " $($color.White)$($color.RedBackground)DevPwsh$($color.Reset)"
    }

    $currentDirectory = dirtrim
    $userName = "$($color.Blue)$Env:UserName$($color.Reset)"

    "${lastCmdTime}${userName} in ${currentDirectory}${gitBranch}${devBuild}`n${lastExit}PS$($color.Reset)$('>' * ($nestedPromptLevel + 1)) "

    # set window title
    # try {
    # 	$prefix = ''
    # 	if ($isWindows) {
    # 		$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    # 		$windowsPrincipal = [Security.Principal.WindowsPrincipal]::new($identity)
    # 		if ($windowsPrincipal.IsInRole('Administrators') -eq 1) {
    # 			$prefix = 'Admin:'
    # 		}
    # 	}

    # 	$Host.ui.RawUI.WindowTitle = "$prefix$PWD"
    # } catch {
    # 	# do nothing if can't be set
    # }

    $global:LASTEXITCODE = $currentLastExitCode
}

# == STARTUP ==
#if (-Not (Get-Module -ListAvailable -Name Pscx)) {
#  Install-Module Pscx -Scope CurrentUser -Force
#}

# == ALIASES ==
if ($PSVersionTable.PSVersion.Major -eq 5) {
    Remove-Item alias:wget
    Remove-Item alias:curl
}
Set-Alias gcif Get-ChildItem -Force

# == FUNCTIONS ==
function Edit-VimRC {
    vim %HOMEPATH%\_vimrc
}

function gst {
    git status
}

# == Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
