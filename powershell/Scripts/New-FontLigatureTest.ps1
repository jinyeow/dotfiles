#Requires -Version 7

<#
.SYNOPSIS
    Render a ligature comparison (Commit / JetBrains / 0xProto) showing what actually fuses.

.DESCRIPTION
    Renders common coding ligatures (-> => == != >= <= :: |> <> ?? etc.) twice per font:
    once with ligatures enabled and once with them disabled (greyed), so you can see exactly
    which sequences each font fuses rather than trusting the font's advertised feature list.
    Each font is subset and embedded as base64 woff2, so the output HTML is self-contained.

    Outputs .font-liga-test.html and .font-liga-test.png at the repo root.

.EXAMPLE
    New-FontLigatureTest

.NOTES
    Windows-only. Requires the fonts installed, Python with fonttools + brotli for subsetting,
    and Edge for the PNG.
#>
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$html = Join-Path $root '.font-liga-test.html'
$png = Join-Path $root '.font-liga-test.png'
$u = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'

$specs = @(
  @{ Alias = 'commit'; Label = 'Commit Mono';   Reg = 'CommitMonoNerdFontMono-Regular.otf' }
  @{ Alias = 'jb';     Label = 'JetBrains Mono'; Reg = 'JetBrainsMonoNerdFontMono-Regular.ttf' }
  @{ Alias = 'ox';     Label = '0xProto';        Reg = '0xProtoNerdFontMono-Regular.ttf' }
)

$lines = @'
-> => ==> <== <-> -->
== === != !== =~ !~
>= <= <=> => -< >-
:: := ... .. |> <| <>
?? ?. ?: && || ++ --
** // /* */ </ /> </>
__ ## www -- ~~ ===
'@

$tmp = Join-Path $env:TEMP 'ligatest'
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

$cards = ''
foreach ($s in $specs) {
  $cards += "<section><h2>$($s.Label)</h2>`n"
  $cards += "<pre class=lig style=`"font-family:'$($s.Alias)',monospace`">$(Enc $lines)</pre>`n"
  $cards += "<div class=note>ligatures ON (calt+liga)</div>`n"
  $cards += "<pre class=raw style=`"font-family:'$($s.Alias)',monospace`">$(Enc $lines)</pre>`n"
  $cards += "<div class=note>ligatures OFF (raw glyphs)</div></section>`n"
}

$doc = @"
<!doctype html><html><head><meta charset=utf-8><style>
$face
  body{background:#1e1e2e;color:#cdd6f4;margin:0;padding:24px 32px;}
  h1{font-family:'Segoe UI',sans-serif;color:#89b4fa;font-size:19px;margin:0 0 6px;}
  .sub{font-family:'Segoe UI',sans-serif;color:#a6adc8;font-size:12px;margin:0 0 18px;}
  .grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;}
  section{background:#181825;border:1px solid #45475a;border-radius:10px;padding:14px 16px;}
  h2{font-family:'Segoe UI',sans-serif;font-size:15px;color:#f5c2e7;margin:0 0 10px;}
  pre{margin:0;font-size:21px;line-height:1.7;white-space:pre;color:#cdd6f4;}
  pre.lig{font-feature-settings:"liga" 1,"calt" 1;}
  pre.raw{font-feature-settings:"liga" 0,"calt" 0;color:#9399b2;}
  .note{font-family:'Segoe UI',sans-serif;font-size:10px;color:#6c7086;margin:4px 0 12px;text-transform:uppercase;letter-spacing:.05em;}
</style></head><body>
<h1>Ligature comparison</h1>
<p class=sub>Top of each card = ligatures enabled; bottom (grey) = same text with ligatures off, so you can see what actually fuses.</p>
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
  & $edge '--headless=new' '--disable-gpu' '--hide-scrollbars' '--force-device-scale-factor=2' "--screenshot=$png" '--window-size=1500,900' $uri 2>$null
  Write-Host "screenshot $png"
}
Write-Host 'DONE'
