#Requires -Version 7
<#
.SYNOPSIS
    Provision Neovim plugins and Treesitter parsers without cloning from `github.com`, for
    machines where it is blocked but `codeload.github.com` (the ZIP host) is reachable.

.DESCRIPTION
    `vim.pack` normally installs plugins by cloning from github.com. On a network that
    blocks that FQDN, the clone fails. This script avoids all github.com network access:

    1. Plugins - reads the committed `nvim-pack-lock.json`, and for each plugin downloads
       a ZIP of the exact pinned revision from codeload.github.com, extracting it into
       `<data>/site/pack/core/opt/<name>`. `vim.pack` treats any directory that matches a
       valid lockfile entry as "installed" and loads it via `:packadd` with no git calls
       (verified against the Neovim 0.12 `vim.pack` source) - so a plain ZIP extract works.

    2. Treesitter parsers - `vim.pack` does not manage these. For each language in
       `lua/config/treesitter.lua`'s `ensure_installed`, the grammar source is fetched from
       codeload (repo from nvim-treesitter's parser config, revision from its `lockfile.json`)
       into a staging dir, then nvim-treesitter compiles it from that LOCAL path. Compiling
       from a local directory skips git (nvim-treesitter `install.lua`), and `zig` is used as
       the C/C++ compiler.

    3. The org grammar - nvim-orgmode does NOT use nvim-treesitter. It clones its own
       `tree-sitter-org` from github.com on first `setup()` and compiles it into its own
       plugin dir, so the blocked network breaks it independently of step 2. The pinned
       source is staged from codeload and orgmode compiles it from that local path.

    Every `nvim` invocation runs WITHOUT the user config (`-u NONE` for path resolution, a
    minimal `-u <init>` that only `packadd`s nvim-treesitter for the parser step). This is
    essential: loading the normal config would run `vim.pack.add`, which would try to clone
    from the blocked github.com before anything is provisioned.

    Idempotent and rev-aware: an item is reinstalled only when missing or when its recorded
    revision differs from the lockfile (plugins track rev in a per-dir `.codeload-rev`
    marker; parsers in a central `.codeload-parser-revs.json`). Run it ON the blocked
    machine, after the dotfiles are present (it reads the repo's own lockfiles).

.NOTES
    The parser step requires a C compiler (`zig` preferred - `winget install zig.zig`;
    `cc`/`gcc`/`clang`/`cl` also work) and the `git` executable on PATH. nvim-treesitter
    refuses its install command without `git` present, but it makes NO network calls here -
    grammar sources come from codeload and compile from a local path. Both are pre-checked.

    The org grammar step needs only the compiler - orgmode shells out to git solely to
    clone, which is exactly what staging from codeload replaces.

.EXAMPLE
    ./Install-PluginsOffline.ps1
    Provision every plugin and parser that is missing or out of date.

.EXAMPLE
    ./Install-PluginsOffline.ps1 -Verbose
    Same, with per-item progress and the headless-nvim output.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# --- Paths -------------------------------------------------------------------

$repoLockfile = Join-Path $PSScriptRoot 'nvim-pack-lock.json'
if (-not (Test-Path $repoLockfile)) {
    throw "vim.pack lockfile not found at '$repoLockfile'. Run this script from the dotfiles 'nvim/' directory."
}

# Resolve Neovim's data dir. `-u NONE` is mandatory: with the normal config, init.lua runs
# vim.pack.add and would try to clone from the (blocked) github.com before provisioning.
$dataDir = (nvim --headless -u NONE -c 'lua io.write(vim.fn.stdpath("data"))' -c 'qa!' 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $dataDir -or -not (Test-Path $dataDir)) {
    throw "Could not resolve Neovim data dir (nvim exit $LASTEXITCODE, got '$dataDir'). Is 'nvim' on PATH?"
}
$optDir = Join-Path $dataDir 'site/pack/core/opt'
New-Item -ItemType Directory -Force -Path $optDir | Out-Null

# --- Helpers -----------------------------------------------------------------

function Get-OwnerRepo {
    # Parse 'owner' and 'repo' out of a https://github.com/owner/repo[.git] source URL.
    # codeload only mirrors github.com, so reject anything else rather than build a bad URL.
    param([Parameter(Mandatory)][string]$Src)
    $uri = [Uri]$Src
    if ($uri.Host -ne 'github.com') {
        throw "Source '$Src' is not a github.com URL; codeload cannot mirror it."
    }
    $segments = $uri.AbsolutePath.Trim('/') -split '/'
    if ($segments.Count -lt 2) { throw "Cannot parse owner/repo from source '$Src'." }
    return [pscustomobject]@{ Owner = $segments[0]; Repo = ($segments[1] -replace '\.git$', '') }
}

function Get-ShortRev {
    param([Parameter(Mandatory)][string]$Rev)
    return $Rev.Substring(0, [Math]::Min(7, $Rev.Length))
}

function Get-OrgLockVersion {
    # orgmode records the grammar version it installed in its own lock file, inside its
    # plugin dir. Returns $null when absent or unreadable so a corrupt lock is treated as
    # "needs provisioning" rather than failing the whole run.
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        return (Get-Content $Path -Raw | ConvertFrom-Json).version
    }
    catch {
        return $null
    }
}

function Install-CodeloadArchive {
    # Download owner/repo at $Rev as a ZIP from codeload and place its contents at $Dest.
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Rev,
        [Parameter(Mandatory)][string]$Dest
    )
    $url = "https://codeload.github.com/$Owner/$Repo/zip/$Rev"
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ("nvimoff_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $scratch | Out-Null
    try {
        $zip = Join-Path $scratch 'archive.zip'
        Invoke-WebRequest -Uri $url -OutFile $zip
        $extracted = Join-Path $scratch 'x'
        Expand-Archive -Path $zip -DestinationPath $extracted
        # codeload archives contain a single top-level folder: <repo>-<rev>
        $top = Get-ChildItem $extracted -Directory | Select-Object -First 1
        if (-not $top) { throw "Archive for $Owner/$Repo@$Rev had no top-level directory." }
        if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
        New-Item -ItemType Directory -Force -Path (Split-Path $Dest -Parent) | Out-Null
        Move-Item $top.FullName $Dest
    }
    finally {
        Remove-Item $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Step 1: plugins ---------------------------------------------------------

Write-Host "==> Provisioning plugins into $optDir" -ForegroundColor Cyan
$plugins = (Get-Content $repoLockfile -Raw | ConvertFrom-Json).plugins
$pluginErrors = @()
$installed = 0
$skipped = 0

foreach ($name in ($plugins.PSObject.Properties.Name | Sort-Object)) {
    $entry = $plugins.$name
    if (-not $entry.src -or -not $entry.rev) {
        $pluginErrors += "${name}: lockfile entry missing src/rev"
        continue
    }
    $dest = Join-Path $optDir $name
    $marker = Join-Path $dest '.codeload-rev'
    # Rev-aware skip: present AND recorded rev matches the lockfile.
    if ((Test-Path $dest) -and (Test-Path $marker) -and ((Get-Content $marker -Raw).Trim() -eq $entry.rev)) {
        Write-Verbose "skip plugin $name (up to date)"
        $skipped++
        continue
    }
    try {
        $or = Get-OwnerRepo -Src $entry.src
        Write-Host "    + $name ($($or.Owner)/$($or.Repo)@$(Get-ShortRev $entry.rev))"
        Install-CodeloadArchive -Owner $or.Owner -Repo $or.Repo -Rev $entry.rev -Dest $dest
        Set-Content -Path $marker -Value $entry.rev -NoNewline
        $installed++
    }
    catch {
        $pluginErrors += "${name}: $($_.Exception.Message)"
    }
}
Write-Host "    plugins: $installed installed, $skipped up to date, $($pluginErrors.Count) failed"

# --- Step 2: Treesitter parsers ---------------------------------------------

$tsDir = Join-Path $optDir 'nvim-treesitter'
$tsLock = Join-Path $tsDir 'lockfile.json'
$tsConfig = Join-Path $PSScriptRoot 'lua/config/treesitter.lua'
$parserErrors = @()

# Shared by the parser step and the org-grammar step below - both compile C from a
# locally staged source tree.
$compiler = @('zig', 'cc', 'gcc', 'clang', 'cl') |
    ForEach-Object { Get-Command $_ -ErrorAction SilentlyContinue } |
    Select-Object -First 1

if (-not (Test-Path $tsLock)) {
    Write-Warning "nvim-treesitter not present ($tsLock missing) - skipping parser step."
}
else {
    # Parser provisioning needs a C compiler and the `git` executable: nvim-treesitter's
    # install command refuses to run without `git` present, even though no network is used
    # here (sources are local). Missing prerequisites are recorded and the step is skipped,
    # so the final summary still reports any plugin failures collected above.
    $hasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
    if (-not $compiler) {
        $parserErrors += "Treesitter parsers skipped: no C compiler on PATH (install e.g. 'winget install zig.zig')."
    }
    elseif (-not $hasGit) {
        $parserErrors += "Treesitter parsers skipped: 'git' executable not on PATH (nvim-treesitter requires it; no network is used)."
    }
    else {
        Write-Host "==> Provisioning Treesitter parsers (compiler: $($compiler.Name))" -ForegroundColor Cyan

        # Languages come from the single source of truth: treesitter.lua's ensure_installed.
        $tsText = Get-Content $tsConfig -Raw
        $block = [regex]::Match($tsText, 'ensure_installed\s*=\s*\{(.+?)\}', 'Singleline')
        if (-not $block.Success) {
            throw "Could not find 'ensure_installed = { ... }' in $tsConfig - parser list is unknown."
        }
        $langs = [regex]::Matches($block.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value }
        $parserOut = Join-Path $tsDir 'parser'
        $revs = Get-Content $tsLock -Raw | ConvertFrom-Json

        # Rev-aware parser tracking (parsers carry no rev of their own once compiled).
        $revFile = Join-Path $tsDir '.codeload-parser-revs.json'
        $haveRevs = @{}
        if (Test-Path $revFile) {
            (Get-Content $revFile -Raw | ConvertFrom-Json).PSObject.Properties |
                ForEach-Object { $haveRevs[$_.Name] = $_.Value }
        }

        # Provision a parser when its .so is missing or its recorded rev differs from the lockfile.
        $needed = $langs | Where-Object {
            $want = $revs.$_.revision
            (-not (Test-Path (Join-Path $parserOut "$_.so"))) -or ($haveRevs[$_] -ne $want)
        }

        if (-not $needed) {
            Write-Host "    parsers: all $($langs.Count) up to date"
        }
        else {
            $staging = Join-Path ([IO.Path]::GetTempPath()) ("nvimts_" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Force -Path $staging | Out-Null
            try {
                # Ask nvim (minimal config) for each grammar's source repo URL, keyed by language.
                # Data crosses the PS<->Lua boundary via files referenced by env vars - no string
                # interpolation into Lua, so paths/quotes/spaces can't break anything.
                $langsFile = Join-Path $staging 'langs.json'
                $urlOutFile = Join-Path $staging 'urls.json'
                # -InputObject (not pipe): piping a 1-element array to ConvertTo-Json unwraps it to
                # a bare JSON string, which Lua's ipairs() can't iterate.
                Set-Content -Path $langsFile -Value (ConvertTo-Json -InputObject @($needed) -Compress) -Encoding utf8
                $env:NVIMOFF_LANGS = $langsFile
                $env:NVIMOFF_URLOUT = $urlOutFile
                $queryInit = Join-Path $staging 'query.lua'
                Set-Content -Path $queryInit -Encoding utf8 -Value @'
vim.cmd('packadd nvim-treesitter')
local langs = vim.json.decode(table.concat(vim.fn.readfile(vim.env.NVIMOFF_LANGS), '\n'))
local cfg = require('nvim-treesitter.parsers').get_parser_configs()
local out = {}
for _, l in ipairs(langs) do if cfg[l] then out[l] = cfg[l].install_info.url end end
vim.fn.writefile({ vim.json.encode(out) }, vim.env.NVIMOFF_URLOUT)
'@
                $queryOut = nvim --headless -u $queryInit -c 'qa!' 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0 -or -not (Test-Path $urlOutFile)) {
                    $parserErrors += "nvim parser-URL query failed (exit $LASTEXITCODE): $queryOut"
                    $urls = $null
                }
                else {
                    $urls = Get-Content $urlOutFile -Raw | ConvertFrom-Json
                }

                # Fetch each grammar's source from codeload at its pinned revision.
                $staged = @{}
                foreach ($lang in ($urls ? $needed : @())) {
                    $src = $urls.$lang
                    $rev = $revs.$lang.revision
                    if (-not $src -or -not $rev) {
                        $parserErrors += "${lang}: missing parser url or revision"
                        continue
                    }
                    try {
                        $or = Get-OwnerRepo -Src $src
                        $dest = Join-Path $staging $lang
                        Write-Host "    + $lang ($($or.Owner)/$($or.Repo)@$(Get-ShortRev $rev))"
                        Install-CodeloadArchive -Owner $or.Owner -Repo $or.Repo -Rev $rev -Dest $dest
                        $staged[$lang] = $dest
                    }
                    catch {
                        $parserErrors += "${lang}: fetch failed - $($_.Exception.Message)"
                    }
                }

                if ($staged.Count -gt 0) {
                    # Compile from the local staged sources. nvim-treesitter treats a local-path
                    # install_info.url as a copy source and skips git. Minimal config (packadd only)
                    # so the user config's vim.pack.add never runs.
                    $stageFile = Join-Path $staging 'stage.json'
                    ($staged | ConvertTo-Json -Compress) | Set-Content -Path $stageFile -Encoding utf8
                    $env:NVIMOFF_STAGE = $stageFile
                    $installInit = Join-Path $staging 'install.lua'
                    Set-Content -Path $installInit -Encoding utf8 -Value @'
vim.cmd('packadd nvim-treesitter')
require('nvim-treesitter.configs').setup({ ensure_installed = {}, auto_install = false })
local stage = vim.json.decode(table.concat(vim.fn.readfile(vim.env.NVIMOFF_STAGE), '\n'))
local cfg = require('nvim-treesitter.parsers').get_parser_configs()
local langs = {}
for lang, path in pairs(stage) do
  if cfg[lang] then
    cfg[lang].install_info.url = path
    langs[#langs + 1] = lang
  end
end
vim.cmd('TSInstallSync! ' .. table.concat(langs, ' '))
'@
                    # Stamp the build start: a parser counts as freshly built only if its .so is
                    # written at/after this point. This is robust to a failed rebuild leaving an
                    # OLD .so in place (a stale binary's mtime predates the build) - so a rev is
                    # never recorded for a parser that didn't actually compile this run. No need to
                    # pre-delete (which could silently fail on a locked file); the old parser also
                    # stays usable if the rebuild fails.
                    $buildStart = Get-Date
                    $installOut = nvim --headless -u $installInit -c 'qa!' 2>&1 | Out-String
                    $installExit = $LASTEXITCODE
                    Write-Verbose $installOut
                    if ($installExit -ne 0) {
                        $parserErrors += "treesitter install: nvim exited $installExit. Output: $installOut"
                    }

                    # Record the rev only for parsers freshly built this run (exists AND rebuilt
                    # at/after $buildStart). A lang that didn't rebuild keeps its prior .so and rev,
                    # so it stays in $needed and is retried next run.
                    foreach ($lang in $staged.Keys) {
                        $so = Get-Item (Join-Path $parserOut "$lang.so") -ErrorAction SilentlyContinue
                        if ($so -and $so.LastWriteTime -ge $buildStart) {
                            $haveRevs[$lang] = $revs.$lang.revision
                        }
                        else {
                            # Drop any prior rev so metadata never claims a parser that isn't freshly
                            # built (keeps $haveRevs consistent and $okCount honest; still retried).
                            $haveRevs.Remove($lang)
                            $parserErrors += "${lang}: parser was not rebuilt (no fresh .so produced)"
                        }
                    }
                    $haveRevs | ConvertTo-Json | Set-Content -Path $revFile -Encoding utf8
                }
            }
            finally {
                Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item Env:NVIMOFF_LANGS, Env:NVIMOFF_URLOUT, Env:NVIMOFF_STAGE -ErrorAction SilentlyContinue
            }
            $okCount = @($needed | Where-Object { $haveRevs[$_] -eq $revs.$_.revision }).Count
            Write-Host "    parsers: $okCount of $(@($needed).Count) provisioned"
        }
    }
}

# --- Step 3: the org grammar -------------------------------------------------

# nvim-orgmode does NOT go through nvim-treesitter: on first setup() it clones
# nvim-orgmode/tree-sitter-org from github.com into stdpath('cache') and compiles it into
# its OWN plugin dir, so step 2 does not cover it and the blocked network breaks it.
# Stage the pinned source from codeload and let orgmode compile it from that local path -
# the same approach as step 2, and it keeps orgmode's own compiler args, install path and
# lock-file format as the single source of truth rather than duplicating them here.
#
# ORDER MATTERS: parser/org.so and .org-ts-lock.json both live INSIDE the plugin dir, so
# this must run AFTER step 1 - re-extracting the plugin wipes them. That also makes
# orgmode's own lock file a self-correcting marker (wiped with the plugin, so a plugin
# update re-triggers this step), which is why there is no .codeload-rev here.

$orgErrors = @()
$orgDir = Join-Path $optDir 'orgmode'
$orgInstallLua = Join-Path $orgDir 'lua/orgmode/utils/treesitter/install.lua'

if (-not (Test-Path $orgDir)) {
    Write-Verbose 'orgmode not installed - skipping org grammar step.'
}
elseif (-not (Test-Path $orgInstallLua)) {
    $orgErrors += "orgmode is present but '$orgInstallLua' is missing - cannot determine the required grammar version."
}
else {
    # orgmode pins the grammar version in its installer; read it rather than hardcode,
    # mirroring how step 2 reads ensure_installed from treesitter.lua.
    $versionMatch = [regex]::Match((Get-Content $orgInstallLua -Raw), "required_version\s*=\s*'([^']+)'")
    if (-not $versionMatch.Success) {
        $orgErrors += "Could not find 'required_version' in $orgInstallLua - the pinned org grammar version is unknown."
    }
    else {
        $orgVersion = $versionMatch.Groups[1].Value
        $orgParser = Join-Path $orgDir 'parser/org.so'
        $orgLock = Join-Path $orgDir '.org-ts-lock.json'

        if ((Test-Path $orgParser) -and (Get-OrgLockVersion -Path $orgLock) -eq $orgVersion) {
            Write-Host "==> org grammar: up to date ($orgVersion)" -ForegroundColor Cyan
        }
        elseif (-not $compiler) {
            $orgErrors += "org grammar skipped: no C compiler on PATH (install e.g. 'winget install zig.zig')."
        }
        else {
            Write-Host "==> Provisioning org grammar (compiler: $($compiler.Name))" -ForegroundColor Cyan
            $orgStaging = Join-Path ([IO.Path]::GetTempPath()) ("nvimorg_" + [guid]::NewGuid().ToString('N'))
            try {
                $orgSrc = Join-Path $orgStaging 'tree-sitter-org'
                Write-Host "    + tree-sitter-org (nvim-orgmode/tree-sitter-org@$orgVersion)"
                Install-CodeloadArchive -Owner 'nvim-orgmode' -Repo 'tree-sitter-org' -Rev $orgVersion -Dest $orgSrc

                # orgmode moves the compiled parser into <plugin>/parser/ but never creates
                # that directory - it ships it (holding only a .gitignore). Recreate it so the
                # natural "delete the parser and re-run to rebuild" recovery works, instead of
                # failing with an opaque "cannot find the path specified" out of the move.
                New-Item -ItemType Directory -Force -Path (Split-Path $orgParser -Parent) | Out-Null

                # orgmode's installer resolves a local directory instead of cloning, but the
                # github URL is hardcoded inside run(), so that branch is unreachable from
                # config. Override get_path to hand it the staged copy. Path crosses the
                # PS<->Lua boundary via an env var - no interpolation into Lua.
                $env:NVIMOFF_ORGSRC = $orgSrc
                $orgInit = Join-Path $orgStaging 'orginstall.lua'
                Set-Content -Path $orgInit -Encoding utf8 -Value @'
vim.cmd('packadd orgmode')
local install = require('orgmode.utils.treesitter.install')
local Promise = require('orgmode.utils.promise')
install.get_path = function()
  return Promise.resolve(vim.env.NVIMOFF_ORGSRC)
end
local ok, err = pcall(function()
  return install.run('install')
end)
if not ok then
  io.stderr:write('org grammar install failed: ' .. tostring(err) .. '\n')
  vim.cmd('cq')
end
'@
                $orgOut = nvim --headless -u $orgInit -c 'qa!' 2>&1 | Out-String
                $orgExit = $LASTEXITCODE
                Write-Verbose $orgOut

                # Trust orgmode's own lock file over the exit code: the grammar counts as
                # provisioned only if the parser exists AND the recorded version matches.
                if ($orgExit -ne 0 -or -not (Test-Path $orgParser) -or (Get-OrgLockVersion -Path $orgLock) -ne $orgVersion) {
                    $orgErrors += "org grammar: build failed (nvim exit $orgExit). Output: $orgOut"
                }
                else {
                    Write-Host "    org grammar: provisioned ($orgVersion)"
                }
            }
            catch {
                $orgErrors += "org grammar: $($_.Exception.Message)"
            }
            finally {
                Remove-Item $orgStaging -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item Env:NVIMOFF_ORGSRC -ErrorAction SilentlyContinue
            }
        }
    }
}

# --- Summary -----------------------------------------------------------------

$allErrors = @($pluginErrors) + @($parserErrors) + @($orgErrors) | Where-Object { $_ }
if ($allErrors.Count -gt 0) {
    Write-Host ""
    Write-Warning "Completed with $($allErrors.Count) failure(s):"
    $allErrors | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    throw "Offline provisioning finished with errors (see above)."
}
Write-Host "All plugins and parsers provisioned." -ForegroundColor Green
