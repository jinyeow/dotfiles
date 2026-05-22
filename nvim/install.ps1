#Requires -Version 7
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$NvimConfigDir  = Join-Path $env:LOCALAPPDATA 'nvim'
$ScriptDir      = $PSScriptRoot
$NvimSourceDir  = $ScriptDir

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Info    { param($Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan    }
function Write-Success { param($Msg) Write-Host "[OK]    $Msg" -ForegroundColor Green   }
function Write-Warn    { param($Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow  }
function Fail          { param($Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red; exit 1 }

function Assert-Command {
  param($Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    Fail "'$Name' is required but not found in PATH."
  }
}

# ── Preflight ─────────────────────────────────────────────────────────────────

Write-Info 'Checking dependencies...'
Assert-Command 'nvim'
Assert-Command 'git'

# ── Backup existing config ────────────────────────────────────────────────────

if (Test-Path $NvimConfigDir) {
  $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $Backup    = "${NvimConfigDir}.bak.${Timestamp}"
  Write-Warn "Existing config found. Backing up to: $Backup"
  Move-Item -Path $NvimConfigDir -Destination $Backup
}

# ── Install ───────────────────────────────────────────────────────────────────

Write-Info "Installing Neovim config to: $NvimConfigDir"
New-Item -ItemType Directory -Path (Join-Path $NvimConfigDir 'lua\config') -Force | Out-Null

$Files = @{
  'init.lua'                   = 'init.lua'
  'lua\config\performance.lua' = 'lua\config\performance.lua'
  'lua\config\user.lua'        = 'lua\config\user.lua'
  'lua\config\plugins.lua'     = 'lua\config\plugins.lua'
  'lua\config\options.lua'     = 'lua\config\options.lua'
  'lua\config\keymaps.lua'     = 'lua\config\keymaps.lua'
  'lua\config\autocmds.lua'    = 'lua\config\autocmds.lua'
  'lua\config\treesitter.lua'  = 'lua\config\treesitter.lua'
  'lua\config\lsp.lua'         = 'lua\config\lsp.lua'
  'lua\config\gitsigns.lua'    = 'lua\config\gitsigns.lua'
  'lua\config\ui.lua'          = 'lua\config\ui.lua'
}

foreach ($Src in $Files.Keys) {
  $SrcPath  = Join-Path $NvimSourceDir $Src
  $DestPath = Join-Path $NvimConfigDir $Files[$Src]
  Copy-Item -Path $SrcPath -Destination $DestPath -Force
}

Write-Success 'Neovim config installed.'
Write-Info 'Open Neovim — plugins will be cloned automatically on first launch.'