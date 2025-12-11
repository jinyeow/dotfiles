# gist:4f51b2f23ae8b90e160877e8a8f29bb5
#Requires -Version 7

# For documentation purposes of required modules. Disabled to speed up PROFILE start time
$null = @'
#Requires -Module @{ ModuleName = 'PSReadLine'; ModuleVersion = '2.2.0' }
#Requires -Module 'PSFzf'
#Requires -Module 'posh-git'
#Requires -Module 'Az.Tools.Predictor'
'@

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

Set-PSReadLineOption -PredictionSource HistoryAndPlugin

# == PSFzf ==
if (Get-Module -ListAvailable -Name 'PSFzf' -ErrorAction SilentlyContinue) {
    Set-Alias -Name frg -Value Invoke-PsFzfRipgrep

    # Replace standard TAB completion
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
    Set-PSReadLineKeyHandler -Chord 'alt+f' -ScriptBlock { Invoke-PsFzfRipgrep -SearchString '.' }

    # example command - use $Location with a different command:
    $commandOverride = [ScriptBlock] { param($Location) Write-Host $Location }

    # pass your override to PSFzf:
    $psFzfOverrides = @{
        AltCCommand = $commandOverride
        EnableAliasFuzzyEdit = $true
        EnableAliasFuzzyGitStatus = $true
        EnableAliasFuzzyHistory = $true
        EnableAliasFuzzyKillProcess = $true
        EnableAliasFuzzySetLocation = $true
        PSReadlineChordProvider = 'Ctrl+t'
        PSReadlineChordReverseHistory = 'Ctrl+r'
    }
    Set-PsFzfOption @psFzfOverrides
}

# == Prompt ==
. "$(Split-Path -Path $PROFILE)/Profile/Set-Prompt.ps1"

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

# == ALIASES ==
if ($PSVersionTable.PSVersion.Major -eq 5) {
    Remove-Item alias:wget
    Remove-Item alias:curl
}

Set-Alias c clear -Force
Set-Alias -Name g -Value git
Set-Alias gcif Get-ChildItem -Force

# == FUNCTIONS ==
function gst {
    git status
}

function which ($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

# == ENVIRONMENT VARIABLES ===
$env:XDG_CONFIG_HOME = "$HOME/.config"

# == Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
# == zoxide ==
# https://github.com/ajeetdsouza/zoxide
# As per documentation, set at the end of the PROFILE
if ($null -ne (Get-Command -Name zoxide -ErrorAction SilentlyContinue)) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58
