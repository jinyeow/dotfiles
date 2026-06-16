#Requires -Version 7

<#
.SYNOPSIS
    Build a self-contained, side-by-side HTML comparison of the candidate coding fonts.

.DESCRIPTION
    Renders every candidate font side by side with:
      * a top "character breadth" panel (alphabets, digits, ambiguous glyphs, symbols, ligatures)
      * a language switcher (PowerShell / C# / Bicep) that swaps every card's code sample live

    Each font is SUBSET to just the glyphs the samples use and embedded as a base64 woff2
    data: URI, so the output HTML is fully self-contained and renders the real fonts when
    opened directly in any browser (plain file:/// @font-face URLs are blocked cross-origin).
    A cropped PNG screenshot is also produced via headless Edge.

    Outputs .font-samples.html and .font-samples.png at the repo root.

.PARAMETER Fonts
    Limit the comparison to a subset, matched case-insensitively against each font's alias or
    label (substring). Omit to compare all candidates.

.EXAMPLE
    New-FontComparison
    Compare all nine candidate fonts.

.EXAMPLE
    New-FontComparison -Fonts jetbrains, commit, 0xproto
    Compare just those three.

.NOTES
    Windows-only. Requires the fonts installed (see Install-CodingFont.ps1), Python with
    fonttools + brotli (pip install fonttools brotli) for subsetting, and Edge for the PNG.
#>
param([string[]]$Fonts)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$html = Join-Path $root '.font-samples.html'
$png = Join-Path $root '.font-samples.png'
$u = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$w = 'C:\Windows\Fonts'

# alias (CSS family) -> label + regular face file + dir
$specs = @(
  @{ Alias = 'fira';   Label = 'Fira Code (current)';     Dir = $w; Reg = 'FiraCode-Regular.ttf' }
  @{ Alias = 'maple';  Label = 'Maple Mono  (applied)';   Dir = $u; Reg = 'MapleMono-NF-Regular.ttf' }
  @{ Alias = 'jb';     Label = 'JetBrains Mono';          Dir = $u; Reg = 'JetBrainsMonoNerdFontMono-Regular.ttf' }
  @{ Alias = 'mona';   Label = 'Monaspace Neon';          Dir = $u; Reg = 'MonaspiceNeNerdFontMono-Regular.otf' }
  @{ Alias = 'ox';     Label = '0xProto';                 Dir = $u; Reg = '0xProtoNerdFontMono-Regular.ttf' }
  @{ Alias = 'iose';   Label = 'Iosevka';                 Dir = $u; Reg = 'IosevkaNerdFontMono-Regular.ttf' }
  @{ Alias = 'victor'; Label = 'Victor Mono';             Dir = $u; Reg = 'VictorMonoNerdFontMono-Regular.ttf' }
  @{ Alias = 'commit'; Label = 'Commit Mono';             Dir = $u; Reg = 'CommitMonoNerdFontMono-Regular.otf' }
  @{ Alias = 'geist';  Label = 'Geist Mono (no italic)';  Dir = $u; Reg = 'GeistMonoNerdFontMono-Regular.otf' }
)

if ($Fonts) {
  $specs = $specs | Where-Object {
    $s = $_; $Fonts | Where-Object { $s.Alias -like "*$_*" -or $s.Label -like "*$_*" }
  }
  if (-not $specs) { throw "no fonts matched: $($Fonts -join ', ')" }
  Write-Host "comparing: $(($specs.Label -join ' | '))"
}

# Broad character set: alphabets, digits, ambiguous glyphs, symbols and ligatures.
$breadth = @'
ABCDEFGHIJKLMNOPQRSTUVWXYZ
abcdefghijklmnopqrstuvwxyz
0123456789   0O Oo l1I|  !? .,;:
=> -> <- <-> == === != !== >= <=
:: := |> <| ++ -- ** /* */ ... ?? ?.
?:  &&  ||  ??=  <>  </ />  #!  ##  @
`~!#$%^&*()_+-={}[]\|;:'",.<>/?  $x #{y}
'@

$ps = @'
function Get-Report {
    [CmdletBinding()]
    param([int]$Top = 10, [string]$Path)
    $items = Get-ChildItem $Path -File |
        Where-Object { $_.Length -ge 1kb -and $_.Name -ne '.gitignore' } |
        Sort-Object Length -Descending | Select-Object -First $Top
    $total = ($items | Measure-Object Length -Sum).Sum ?? 0   # null-coalescing
    $items.Count -gt 0 ? "OK ($total)" : "empty"              # ternary
}
'@

$cs = @'
public async Task<IReadOnlyList<User>> GetActiveAsync(int minAge = 18) {
    var users = await _db.Users
        .Where(u => u.Age >= minAge && u.IsActive != false)  // => >= && !=
        .Select(u => new { u.Id, u.Name })
        .ToListAsync();
    return users.Count == 0 ? Array.Empty<User>()            // == ?
        : users.Where(u => u.Name?.Length > 0 ?? false).ToList();  // ?. ??
}
'@

$bicep = @'
param location string = resourceGroup().location
var isProd = env == 'prod'                                   // ==
var sku = isProd ? 'Premium_LRS' : 'Standard_LRS'            // ternary
resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${uniqueString(resourceGroup().id)}'             // interpolation
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: env != 'prod' && false           // != &&
  }
}
'@

# --- Subset each face to the used glyphs and embed as base64 woff2 ---
$tmp = Join-Path $env:TEMP 'fontsubset'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$charsFile = Join-Path $tmp 'chars.txt'
Set-Content -Path $charsFile -Value ($breadth, $ps, $cs, $bicep -join "`n") -Encoding utf8

function EmbedFace([string]$path, [string]$tag) {
  $out = Join-Path $tmp "$tag.woff2"
  # default layout-feature closure keeps liga/calt/clig/rlig, so coding ligatures survive
  & python -m fontTools.subset $path "--text-file=$charsFile" "--output-file=$out" --flavor=woff2 2>&1 | Out-Null
  # Fail loud: a missing subset would emit an empty @font-face and silently render a
  # fallback font, invalidating the comparison.
  if (-not (Test-Path $out)) { throw "fontTools.subset failed for '$path' (exit $LASTEXITCODE) — is Python with fonttools + brotli installed?" }
  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($out))
  return "data:font/woff2;base64,$b64"
}

# Build @font-face rules (regular/italic/bold) for whatever files exist
$face = ''
foreach ($s in $specs) {
  $ext = [IO.Path]::GetExtension($s.Reg)
  $base = $s.Reg -replace '-Regular\.(ttf|otf)$', ''
  $regP = Join-Path $s.Dir $s.Reg
  $itP = Join-Path $s.Dir "$base-Italic$ext"
  $bdP = Join-Path $s.Dir "$base-Bold$ext"
  if (-not (Test-Path $regP)) { Write-Warning "missing regular: $regP"; continue }
  $reg = EmbedFace $regP "$($s.Alias)-reg"
  $face += "@font-face{font-family:'$($s.Alias)';font-weight:400;font-style:normal;src:url('$reg') format('woff2');}`n"
  if (Test-Path $itP) {
    $it = EmbedFace $itP "$($s.Alias)-it"
    $face += "@font-face{font-family:'$($s.Alias)';font-weight:400;font-style:italic;src:url('$it') format('woff2');}`n"
  }
  if (Test-Path $bdP) {
    $bd = EmbedFace $bdP "$($s.Alias)-bd"
    $face += "@font-face{font-family:'$($s.Alias)';font-weight:700;font-style:normal;src:url('$bd') format('woff2');}`n"
  }
}
Remove-Item $tmp -Recurse -Force

function EncodePlain([string]$s) {
  return ($s -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
}
function Encode([string]$s) {
  $s = EncodePlain $s
  return [regex]::Replace($s, '(#[^\r\n]*|//[^\r\n]*)', '<span class="cmt">$1</span>')
}

# Top panel: every font rendering the same broad character set, side by side.
$breadthCards = ''
foreach ($s in $specs) {
  $breadthCards += "<section style=`"font-family:'$($s.Alias)',monospace`">`n"
  $breadthCards += "  <h2>$($s.Label)</h2>`n"
  $breadthCards += "  <pre class=breadth>$(EncodePlain $breadth)</pre>`n"
  $breadthCards += "</section>`n"
}

# Language panel: each card carries all three samples; CSS shows only the active language.
$codeCards = ''
foreach ($s in $specs) {
  $codeCards += "<section style=`"font-family:'$($s.Alias)',monospace`">`n"
  $codeCards += "  <h2>$($s.Label)</h2>`n"
  foreach ($pair in @(@('ps', $ps), @('cs', $cs), @('bicep', $bicep))) {
    $codeCards += "  <pre data-lang=$($pair[0])>$(Encode $pair[1])</pre>`n"
  }
  $codeCards += "</section>`n"
}

$doc = @"
<!doctype html><html><head><meta charset=utf-8><title>Coding font comparison</title><style>
$face
  :root { --bg:#1e1e2e; --card:#181825; --line:#45475a; --txt:#cdd6f4; }
  * { box-sizing:border-box; }
  body { background:var(--bg); color:var(--txt); margin:0; padding:0 0 40px;
         font-feature-settings:"liga" 1,"calt" 1; font-variant-ligatures:contextual; }
  header { padding:24px 36px 0; }
  h1 { font-family:'Segoe UI',sans-serif; color:#89b4fa; font-size:20px; margin:0 0 4px; }
  .sub { font-family:'Segoe UI',sans-serif; color:#a6adc8; font-size:13px; margin:0 0 6px; }
  h3 { font-family:'Segoe UI',sans-serif; color:#94e2d5; font-size:14px; font-weight:600;
       text-transform:uppercase; letter-spacing:.08em; margin:26px 36px 12px; }
  .grid { display:grid; grid-template-columns:repeat(2, minmax(0,1fr)); gap:16px; padding:0 36px; }
  section { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:14px 18px; }
  h2 { font-family:'Segoe UI',sans-serif; font-size:16px; color:#f5c2e7; margin:0 0 10px; }
  pre { margin:0; font-size:14px; line-height:1.55; white-space:pre; color:var(--txt); overflow-x:auto; }
  pre.breadth { font-size:15px; line-height:1.7; }
  .cmt { color:#7f849c; font-style:italic; }
  .tabs { position:sticky; top:0; z-index:5; background:var(--bg); padding:14px 36px 12px;
          margin-top:6px; border-bottom:1px solid var(--line); }
  .tabs span { font-family:'Segoe UI',sans-serif; color:#a6adc8; font-size:13px; margin-right:10px; }
  .tabs button { font-family:'Segoe UI',sans-serif; font-size:13px; cursor:pointer;
                 color:var(--txt); background:#313244; border:1px solid var(--line);
                 border-radius:7px; padding:6px 14px; margin-right:8px; }
  .tabs button.active { background:#89b4fa; color:#11111b; border-color:#89b4fa; font-weight:600; }
  .code-grid pre { display:none; }
  body[data-lang="ps"]    .code-grid pre[data-lang="ps"],
  body[data-lang="cs"]    .code-grid pre[data-lang="cs"],
  body[data-lang="bicep"] .code-grid pre[data-lang="bicep"] { display:block; }
</style></head><body data-lang="ps">
<header>
  <h1>Coding font comparison</h1>
  <p class=sub>Fonts subset to the sample glyphs and embedded (base64 woff2) — self-contained, renders the real fonts in any browser. Ligatures (=&gt; != == ?? ?.) and cursive italics are real.</p>
</header>

<h3>Character breadth</h3>
<div class=grid>
$breadthCards
</div>

<div class=tabs>
  <span>Language:</span>
  <button data-lang=ps class=active>PowerShell</button>
  <button data-lang=cs>C#</button>
  <button data-lang=bicep>Bicep</button>
</div>
<div class="grid code-grid">
$codeCards
</div>

<script>
  const tabs = document.querySelectorAll('.tabs button');
  tabs.forEach(b => b.addEventListener('click', () => {
    document.body.dataset.lang = b.dataset.lang;
    tabs.forEach(x => x.classList.toggle('active', x === b));
  }));
</script>
</body></html>
"@

Set-Content -Path $html -Value $doc -Encoding utf8
Write-Host "wrote $html"

$edge = @(
  'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
  'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { $edge = (Get-Command msedge -ErrorAction SilentlyContinue).Source }
if (-not $edge) { $edge = (Get-Command chrome -ErrorAction SilentlyContinue).Source }

if ($edge) {
  $uri = ([Uri]$html).AbsoluteUri
  if (Test-Path $png) { Remove-Item $png -Force }
  $sargs = @(
    '--headless=new'; '--disable-gpu'; '--no-sandbox'; '--hide-scrollbars'; '--allow-file-access-from-files'
    '--force-device-scale-factor=2'; ('--screenshot="{0}"' -f $png)
    '--window-size=1500,6000'; $uri
  )
  $p = Start-Process $edge -ArgumentList $sargs -NoNewWindow -Wait -PassThru
  if (Test-Path $png) {
    Add-Type -AssemblyName System.Drawing
    $src = [System.Drawing.Bitmap]::FromFile($png)
    $bg = [System.Drawing.Color]::FromArgb(30, 30, 46)
    $isBg = { param($c) ([math]::Abs($c.R - $bg.R) -le 6 -and [math]::Abs($c.G - $bg.G) -le 6 -and [math]::Abs($c.B - $bg.B) -le 6) }
    $bottom = $src.Height
    for ($y = $src.Height - 1; $y -ge 0; $y--) {
      $rowHasContent = $false
      for ($x = 0; $x -lt $src.Width; $x += 80) {
        if (-not (& $isBg $src.GetPixel($x, $y))) { $rowHasContent = $true; break }
      }
      if ($rowHasContent) { $bottom = [math]::Min($src.Height, $y + 56); break }
    }
    $crop = New-Object System.Drawing.Bitmap($src.Width, $bottom)
    $g = [System.Drawing.Graphics]::FromImage($crop)
    $g.DrawImage($src, 0, 0, (New-Object System.Drawing.Rectangle(0, 0, $src.Width, $bottom)), [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose(); $src.Dispose()
    $crop.Save($png, [System.Drawing.Imaging.ImageFormat]::Png); $crop.Dispose()
    Write-Host "screenshot $png (cropped to ${bottom}px)"
  } else { Write-Warning "no screenshot (edge exit $($p.ExitCode))" }
} else {
  Write-Warning 'no Edge/Chrome found for screenshot; open the HTML manually'
}
Write-Host 'DONE'
