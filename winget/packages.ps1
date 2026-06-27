#Requires -Version 7
<#
.SYNOPSIS
    Install curated dev and utility packages via winget.

.DESCRIPTION
    Bootstraps a new Windows machine with hand-picked tools. Run after a fresh
    Windows install. Skips packages that are already installed.

.EXAMPLE
    .\packages.ps1
    .\packages.ps1 -DryRun
#>
param([switch] $DryRun)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Install-Package ([string]$Id, [string]$Source = 'winget') {
    if ($DryRun) {
        Write-Host "[DRY RUN] winget install $Id" -ForegroundColor Cyan
        return
    }
    Write-Host "Installing $Id..." -ForegroundColor Cyan
    winget install --id $Id --source $Source --silent --accept-package-agreements --accept-source-agreements
}

if ($DryRun) { Write-Host 'DRY RUN — no packages will be installed.' -ForegroundColor Yellow }

# ── Editors ───────────────────────────────────────────────────────────────────
Write-Host "`n=== Editors ===" -ForegroundColor Green
Install-Package 'Microsoft.VisualStudioCode'
Install-Package 'Neovim.Neovim'
Install-Package 'vim.vim'
Install-Package 'ZedIndustries.Zed'

# ── Terminal / shell utilities ────────────────────────────────────────────────
Write-Host "`n=== Terminal / shell utilities ===" -ForegroundColor Green
Install-Package 'Microsoft.PowerShell'
Install-Package 'Microsoft.WindowsTerminal'
Install-Package 'Zellij.Zellij'
Install-Package 'sxyazi.yazi'
Install-Package 'sharkdp.bat'
Install-Package 'BurntSushi.ripgrep.GNU'
Install-Package 'ast-grep.ast-grep'
Install-Package 'dandavison.delta'
Install-Package 'sharkdp.fd'
Install-Package 'junegunn.fzf'
Install-Package 'ajeetdsouza.zoxide'
Install-Package 'uutils.coreutils'
Install-Package 'eza-community.eza'
Install-Package 'chmln.sd'
Install-Package 'jqlang.jq'
Install-Package 'MikeFarah.yq'

# ── Git ───────────────────────────────────────────────────────────────────────
Write-Host "`n=== Git ===" -ForegroundColor Green
Install-Package 'Git.Git'
Install-Package 'GitHub.cli'
Install-Package 'GitTools.GitVersion'
Install-Package 'jj-vcs.jj'
Install-Package 'JesseDuffield.lazygit'
Install-Package 'JesseDuffield.Lazydocker'

# ── Languages ─────────────────────────────────────────────────────────────────
Write-Host "`n=== Languages ===" -ForegroundColor Green
Install-Package 'GoLang.Go'
Install-Package 'Volta.Volta'
Install-Package 'OpenJS.NodeJS.22'
Install-Package 'Python.Python.3.14'
Install-Package 'Python.Launcher'
Install-Package 'astral-sh.uv'
Install-Package 'Erlang.ErlangOTP'
Install-Package 'Gleam.Gleam'
Install-Package 'odin-lang.Odin'
Install-Package 'Microsoft.DotNet.SDK.10'
Install-Package 'Microsoft.NuGet'

# ── Azure / cloud ─────────────────────────────────────────────────────────────
Write-Host "`n=== Azure / cloud ===" -ForegroundColor Green
Install-Package 'Microsoft.AzureCLI'
Install-Package 'Microsoft.Azure.FunctionsCoreTools'
Install-Package 'Microsoft.Bicep'
Install-Package 'Pulumi.Pulumi'
Install-Package 'Hashicorp.Terraform'
Install-Package 'Infracost.Infracost'
Install-Package 'Microsoft.FoundryLocal'

# ── Containers / Kubernetes ───────────────────────────────────────────────────
Write-Host "`n=== Containers / Kubernetes ===" -ForegroundColor Green
Install-Package 'RedHat.Podman'
Install-Package 'wagoodman.dive'
Install-Package 'Kubernetes.kubectl'
Install-Package 'Kubernetes.kind'
Install-Package 'k3d.k3d'
Install-Package 'Kubernetes.minikube'

# ── CLI utilities ─────────────────────────────────────────────────────────────
Write-Host "`n=== CLI utilities ===" -ForegroundColor Green
Install-Package 'Task.Task'
Install-Package 'JohnMacFarlane.Pandoc'
Install-Package 'ShiningLight.OpenSSL.Dev'
Install-Package 'ar51an.iPerf3'
Install-Package 'PuTTY.PuTTY'
Install-Package 'cURL.cURL'
Install-Package 'Gyan.FFmpeg'
Install-Package 'yt-dlp.yt-dlp'

# ── Windows utilities ─────────────────────────────────────────────────────────
Write-Host "`n=== Windows utilities ===" -ForegroundColor Green
Install-Package 'Microsoft.PowerToys'
Install-Package 'Microsoft.CmdPalAzureExtension'
Install-Package 'Microsoft.CmdPalGitHubExtension'
Install-Package 'davidegiacometti.EdgeFavoritesForCmdPal'
Install-Package 'Greenshot.Greenshot'
Install-Package 'AntoineAflalo.SoundSwitch'
Install-Package 'GermanCoding.SyncTrayzor'
Install-Package 'DominikReichl.KeePass'
Install-Package '7zip.7zip'

# ── Media / productivity ──────────────────────────────────────────────────────
Write-Host "`n=== Media / productivity ===" -ForegroundColor Green
Install-Package 'VideoLAN.VLC'
Install-Package 'OBSProject.OBSStudio'
Install-Package 'Obsidian.Obsidian'
Install-Package 'Anki.Anki'
Install-Package 'Anthropic.Claude'
Install-Package 'Discord.Discord'
Install-Package 'Tencent.WeChat.Universal'
Install-Package 'Google.GoogleDrive'

# ── Browsers ──────────────────────────────────────────────────────────────────
Write-Host "`n=== Browsers ===" -ForegroundColor Green
Install-Package 'Mozilla.Firefox'
Install-Package 'Zen-Team.Zen-Browser'

# ── WSL ───────────────────────────────────────────────────────────────────────
Write-Host "`n=== WSL ===" -ForegroundColor Green
Install-Package 'Microsoft.WSL'
Install-Package 'Debian.Debian'

Write-Host "`nDone." -ForegroundColor Green
