#Requires -Version 7

<#
.SYNOPSIS
    Switch the coding font across every dotfiles target at once (Windows Terminal, VS Code, Vim).

.DESCRIPTION
    Rewrites the font face in every place this dotfiles repo configures it:
      * Windows Terminal - live LocalState settings.json AND the repo copy
      * VS Code          - live %APPDATA%\Code\User\settings.json AND the repo snapshot
      * Vim (GUI)        - repo vim/vimrc and vim/sources/colors.vim guifont

    Windows Terminal and VS Code apply the change as soon as they next read their live
    settings; Vim is a repo dotfile only (the active Neovim runs in the terminal and inherits
    the Windows Terminal font). A target that is missing on this machine (app not installed,
    or no font setting in the file) is warned about and skipped rather than treated as an error.

    Only the Windows Terminal face name is stored per font; the VS Code family and Vim guifont
    are derived from it - VS Code appends a "Fira Code, monospace" fallback chain, and Vim
    swaps spaces for underscores and appends the GUI size/charset spec.

.PARAMETER Name
    The font to switch to: fira, jetbrains, maple, monaspace, 0xproto, iosevka, victor,
    commit, geist.

.EXAMPLE
    Set-CodingFont commit
    Switch Windows Terminal, VS Code and Vim to CommitMono Nerd Font Mono.

.EXAMPLE
    Set-CodingFont fira
    Revert every target to Fira Code.

.NOTES
    Windows-only. The font must already be installed - see Install-CodingFont.ps1 for the
    Nerd Font candidates (Maple and Fira are installed separately).
#>

param([Parameter(Mandatory)][ValidateSet('fira', 'jetbrains', 'maple', 'monaspace', '0xproto', 'iosevka', 'victor', 'commit', 'geist')][string]$Name)
$ErrorActionPreference = 'Stop'

# Short name -> installed Windows Terminal face (the font family as registered on the system).
$faces = @{
  fira      = 'Fira Code'
  jetbrains = 'JetBrainsMono NFM'
  maple     = 'Maple Mono NF'
  monaspace = 'MonaspiceNe NFM'
  '0xproto' = '0xProto Nerd Font Mono'
  iosevka   = 'Iosevka NFM'
  victor    = 'VictorMono NFM'
  commit    = 'CommitMono Nerd Font Mono'
  geist     = 'GeistMono NFM'
}
$face = $faces[$Name]
$vscodeFamily = "$face, Fira Code, monospace"
$vimGuifont = ($face -replace ' ', '_') + ':h10:cANSI:qDRAFT'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

# Replace every regex match in a file, in place, preserving the original trailing newline.
# Strict: a repo dotfile that is missing or has no font setting is a real error (the repo is
# the source of truth and must always update), so this throws rather than skipping silently.
function Update-FontInFile {
  param([string]$Path, [string]$Pattern, [string]$Replacement, [string]$Label)
  if (-not (Test-Path -LiteralPath $Path)) { throw "${Label}: file not found ($Path)" }
  $text = Get-Content -LiteralPath $Path -Raw
  $rx = [regex]$Pattern
  if (-not $rx.IsMatch($text)) { throw "${Label}: no font setting matched ($Path)" }
  $new = $rx.Replace($text, $Replacement)
  if ($new -ceq $text) { Write-Host "  $Label (already set)"; return }
  Set-Content -LiteralPath $Path -Value $new -NoNewline -Encoding utf8
  Write-Host "  $Label"
}

# A live application target is optional: the app may not be installed on this machine, which is
# fine (warn + skip). But if it IS present, defer to the strict updater so a real anomaly (an
# installed app whose settings lack the font key) still surfaces.
function Update-LiveFont {
  param([string]$Path, [string]$Pattern, [string]$Replacement, [string]$Label)
  if (Test-Path -LiteralPath $Path) { Update-FontInFile $Path $Pattern $Replacement $Label }
  else { Write-Warning "skip ${Label}: app not installed ($Path)" }
}

Write-Host "Setting coding font -> '$face'"

# Windows Terminal: live (optional) + repo.  "face": "<family>"
$wtPat = '("face"\s*:\s*")[^"]*(")'
Update-LiveFont (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json') $wtPat "`${1}$face`${2}" 'Windows Terminal (live)'
Update-FontInFile (Join-Path $repoRoot 'windowsterminal\settings.json') $wtPat "`${1}$face`${2}" 'Windows Terminal (repo)'

# VS Code: live (optional) + repo snapshot.  "editor.fontFamily": "<family>, ..."
$codePat = '("editor\.fontFamily"\s*:\s*")[^"]*(")'
Update-LiveFont (Join-Path $env:APPDATA 'Code\User\settings.json') $codePat "`${1}$vscodeFamily`${2}" 'VS Code (live)'
Update-FontInFile (Join-Path $repoRoot 'vscode\settings.json') $codePat "`${1}$vscodeFamily`${2}" 'VS Code (repo)'

# Vim (GUI) guifont: repo dotfiles only.
$vimPat = '(set guifont=)\S+'
Update-FontInFile (Join-Path $repoRoot 'vim\vimrc') $vimPat "`${1}$vimGuifont" 'Vim (vimrc)'
Update-FontInFile (Join-Path $repoRoot 'vim\sources\colors.vim') $vimPat "`${1}$vimGuifont" 'Vim (colors.vim)'

Write-Host "Done. Windows Terminal + VS Code apply on next settings read; Vim is a repo dotfile."
