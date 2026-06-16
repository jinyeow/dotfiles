#Requires -Version 7

<#
.SYNOPSIS
    Download, per-user install, and activate Nerd Font (Mono) coding fonts in the current session.

.DESCRIPTION
    For each requested font this:
      1. Downloads the archive from the ryanoasis/nerd-fonts release,
      2. Extracts the "*NerdFontMono-{Regular,Italic,Bold,BoldItalic}" faces (whether the font
         ships .ttf or .otf),
      3. Copies them into the per-user font folder (%LOCALAPPDATA%\Microsoft\Windows\Fonts)
         and registers them under HKCU so they survive a restart,
      4. Activates them in the running session via AddFontResource + a WM_FONTCHANGE broadcast,
         so apps pick them up without a logoff.

    Per-user install needs no admin rights. After installing, use Set-CodingFont to switch the
    dotfiles to one of them. (Fira Code and Maple Mono are not Nerd Font archives and are
    installed separately.)

.PARAMETER Name
    One or more Nerd Font archive names to install: JetBrainsMono, Monaspace, 0xProto, Iosevka,
    VictorMono, CommitMono, GeistMono, FiraCode.

.PARAMETER Version
    The nerd-fonts release tag to pull from. Defaults to v3.4.0.

.EXAMPLE
    Install-CodingFont CommitMono
    Install and activate CommitMono Nerd Font Mono.

.EXAMPLE
    Install-CodingFont VictorMono, GeistMono -Version v3.4.0
    Install several at once.

.NOTES
    Windows-only. Requires internet access to the GitHub release.
#>
param(
  [Parameter(Mandatory)]
  [ValidateSet('JetBrainsMono', 'Monaspace', '0xProto', 'Iosevka', 'VictorMono', 'CommitMono', 'GeistMono', 'FiraCode')]
  [string[]]$Name,
  [string]$Version = 'v3.4.0'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
# Mono variants only, all four standard styles, either container format.
$wanted = 'NerdFontMono-(Regular|Italic|Bold|BoldItalic)\.(ttf|otf)$'

# Download with retry-then-raise (transient GitHub/network failures are common).
function Get-FontArchive {
  param([string]$Url, [string]$OutFile, [int]$MaxAttempts = 3)
  for ($i = 1; $i -le $MaxAttempts; $i++) {
    try { Invoke-WebRequest -Uri $Url -OutFile $OutFile; return }
    catch {
      if ($i -eq $MaxAttempts) { throw "download failed after $MaxAttempts attempts ($Url): $($_.Exception.Message)" }
      Write-Warning "download attempt $i/$MaxAttempts failed ($Url): $($_.Exception.Message); retrying"
      Start-Sleep -Seconds ($i * 2)
    }
  }
}

$installed = @()
foreach ($n in $Name) {
  $tmp = Join-Path $env:TEMP "fontdl_$n"; $zip = "$tmp.zip"
  try {
    Write-Host "==> $n : downloading ($Version)"
    Get-FontArchive -Url "https://github.com/ryanoasis/nerd-fonts/releases/download/$Version/$n.zip" -OutFile $zip
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $files = Get-ChildItem -Path $tmp -Recurse -File | Where-Object { $_.Name -match $wanted }
    if (-not $files) { Write-Warning "    no *NerdFontMono faces found in $n.zip" }
    foreach ($f in $files) {
      $dest = Join-Path $fontDir $f.Name
      Copy-Item $f.FullName $dest -Force
      $tag = if ($f.Extension -ieq '.otf') { ' (OpenType)' } else { ' (TrueType)' }
      New-ItemProperty -Path $regPath -Name ([IO.Path]::GetFileNameWithoutExtension($f.Name) + $tag) -Value $f.Name -PropertyType String -Force | Out-Null
      $installed += $dest
      Write-Host "    $($f.Name)"
    }
  }
  finally {
    if (Test-Path $zip) { Remove-Item $zip -Force }
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  }
}

if (-not $installed) { Write-Warning 'nothing installed'; return }

# Activate in the current session so apps see the fonts without a logoff.
# SendMessageTimeout (not SendMessage) so an unresponsive top-level window can't hang the
# broadcast: SMTO_ABORTIFHUNG + a 1s timeout per window.
$sig = @"
[DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceW(string lpFileName);
[DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.IntPtr wParam, System.IntPtr lParam, uint fuFlags, uint uTimeout, out System.UIntPtr lpdwResult);
"@
# Add-Type caches by name within a session; reuse the type if this script is run twice.
$api = try { [Win32.FontActivate] } catch { Add-Type -MemberDefinition $sig -Name FontActivate -Namespace Win32 -PassThru }
$ok = 0; foreach ($p in $installed) { if ($api::AddFontResourceW($p) -gt 0) { $ok++ } }
$res = [UIntPtr]::Zero
[void]$api::SendMessageTimeout([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 0x0002, 1000, [ref]$res)  # HWND_BROADCAST, WM_FONTCHANGE, SMTO_ABORTIFHUNG
Write-Host "activated $ok / $($installed.Count) faces"

# Verify the families are now visible to GDI+.
Add-Type -AssemblyName System.Drawing
$names = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
$installed | ForEach-Object {
  $pfc = New-Object System.Drawing.Text.PrivateFontCollection; $pfc.AddFontFile($_)
  $fam = $pfc.Families[0].Name
  $present = if ($names -contains $fam) { 'YES' } else { 'no (restart may be needed)' }
  "{0,-40} family '{1}' -> installed: {2}" -f [IO.Path]::GetFileName($_), $fam, $present
}
Write-Host 'DONE'
