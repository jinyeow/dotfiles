# gist:4f51b2f23ae8b90e160877e8a8f29bb5
#Requires -Version 7

$null = @'
#Requires -Module @{ ModuleName = 'PSReadLine'; ModuleVersion = '2.2.0' }
'@

# === TROUBLESHOOT STARTUP ===
# Set-PSDebug -Trace 1
# Install-Module PSProfiler
# Import-Module PSProfiler
# Measure-Script -Top 3 $profile

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
. "$(Split-Path -Path $PROFILE)/Profile/Set-Prompt.ps1"

# === PSFzf ===
if (Get-Module -ListAvailable -Name 'PSFzf' -ErrorAction SilentlyContinue) {
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

function which ($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

$_chocoProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if ($_chocoProfile -and (Test-Path $_chocoProfile)) {
    function chocoRefresh {
        Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
        RefreshEnv
    }
}
Remove-Variable _chocoProfile

# === zoxide ===
# https://github.com/ajeetdsouza/zoxide
# As per documentation, set at the end of the PROFILE
if ($null -ne (Get-Command -Name zoxide -ErrorAction SilentlyContinue)) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

