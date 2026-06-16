#Requires -Version 7

<#
.SYNOPSIS
    Render a glyph-separation "torture test" comparing Commit, JetBrains and 0xProto.

.DESCRIPTION
    Renders classic glyph-separation traps - pairs that can fuse into a different glyph at
    tight spacing (rn/m, cl/d, vv/w), and ambiguity sets (1lI|, 0O) - in each font at three
    sizes (12/14/17px), so separation problems that only appear small are visible. Each font
    is subset and embedded as base64 woff2, so the output HTML is self-contained.

    Outputs .font-glyph-test.html and .font-glyph-test.png at the repo root.

.EXAMPLE
    New-FontGlyphTest

.NOTES
    Windows-only. Requires the fonts installed, Python with fonttools + brotli for subsetting,
    and Edge for the PNG.
#>
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$html = Join-Path $root '.font-glyph-test.html'
$png = Join-Path $root '.font-glyph-test.png'
$u = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'

$specs = @(
  @{ Alias = 'commit'; Label = 'Commit Mono';   Reg = 'CommitMonoNerdFontMono-Regular.otf' }
  @{ Alias = 'jb';     Label = 'JetBrains Mono'; Reg = 'JetBrainsMonoNerdFontMono-Regular.ttf' }
  @{ Alias = 'ox';     Label = '0xProto';        Reg = '0xProtoNerdFontMono-Regular.ttf' }
)

# Classic glyph-separation traps: pairs that fuse into a different glyph at tight spacing.
$lines = @'
rn rn rn   vs   m m m
cl cl cl   vs   d d d
vv vv vv   vs   w w w
ll  Il  1l  l1  I1  |l  lll
0O  O0  oO  Oo  0o  o0
mm nn rnrn mrnm  burned/bumed
illlIl1|jJ  clarity  modern
((({[<>]}))) ;;; ::: ... ___
arr[i]; obj.fn(); a,b; e.g. fig.1
'@

$tmp = Join-Path $env:TEMP 'glyphtest'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$charsFile = Join-Path $tmp 'chars.txt'
Set-Content -Path $charsFile -Value $lines -Encoding utf8

$face = ''
foreach ($s in $specs) {
  $regP = Join-Path $u $s.Reg
  if (-not (Test-Path $regP)) { Write-Warning "missing: $regP"; continue }
  $out = Join-Path $tmp "$($s.Alias).woff2"
  & python -m fontTools.subset $regP "--text-file=$charsFile" "--output-file=$out" --flavor=woff2 2>&1 | Out-Null
  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($out))
  $face += "@font-face{font-family:'$($s.Alias)';src:url('data:font/woff2;base64,$b64') format('woff2');}`n"
}
Remove-Item $tmp -Recurse -Force

function Enc([string]$s) { $s -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' }

# For each font, render the same lines at three sizes (separation issues grow at small px).
$cards = ''
foreach ($s in $specs) {
  $cards += "<section style=`"font-family:'$($s.Alias)',monospace`"><h2>$($s.Label)</h2>`n"
  foreach ($px in 12, 14, 17) {
    $cards += "<div class=sz>${px}px</div><pre style=`"font-size:${px}px`">$(Enc $lines)</pre>`n"
  }
  $cards += "</section>`n"
}

$doc = @"
<!doctype html><html><head><meta charset=utf-8><style>
$face
  body{background:#1e1e2e;color:#cdd6f4;margin:0;padding:24px 32px;font-feature-settings:"liga" 1,"calt" 1;}
  h1{font-family:'Segoe UI',sans-serif;color:#89b4fa;font-size:19px;margin:0 0 16px;}
  .grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;}
  section{background:#181825;border:1px solid #45475a;border-radius:10px;padding:14px 16px;}
  h2{font-family:'Segoe UI',sans-serif;font-size:15px;color:#f5c2e7;margin:0 0 8px;}
  .sz{font-family:'Segoe UI',sans-serif;color:#fab387;font-size:11px;margin:10px 0 2px;text-transform:uppercase;letter-spacing:.05em;}
  pre{margin:0;line-height:1.5;white-space:pre;color:#cdd6f4;}
</style></head><body>
<h1>Glyph-separation torture test — rn/m · cl/d · vv/w · 1lI| · 0O</h1>
<div class=grid>
$cards
</div>
</body></html>
"@
Set-Content -Path $html -Value $doc -Encoding utf8
Write-Host "wrote $html"

$edge = @('C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', 'C:\Program Files\Microsoft\Edge\Application\msedge.exe') |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if ($edge) {
  $uri = ([Uri]$html).AbsoluteUri
  if (Test-Path $png) { Remove-Item $png -Force }
  & $edge '--headless=new' '--disable-gpu' '--hide-scrollbars' '--force-device-scale-factor=2' "--screenshot=$png" '--window-size=1500,1100' $uri 2>$null
  Write-Host "screenshot $png"
}
Write-Host 'DONE'
