#Requires -Version 7
# Pester tests for nvim/lua/config/statusline.lua. Each case starts headless Neovim with
# --clean (no user config, no plugins), loads only the statusline module from this repo,
# and asserts the bar text that nvim_eval_statusline returns for fixed widths.
# Fixtures live under a fake HOME in TestDrive so `~` shortening is deterministic.

BeforeAll {
    $script:nvim = Get-Command nvim -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $script:nvim) {
        throw 'nvim is not on PATH. Install Neovim 0.12+ to run tests/nvim-statusline.Tests.ps1 (this suite never skips).'
    }
    $script:nvimConfig = Join-Path (Split-Path $PSScriptRoot -Parent) 'nvim'

    # Hermetic env: fake HOME (also isolates git's global config), isolated XDG dirs, and a
    # git ceiling so the non-git fixture never resolves to a repo above TestDrive.
    $script:envKeys = @(
        'HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME',
        'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM', 'GIT_CEILING_DIRECTORIES', 'NVIM_PROFILE'
    )
    $script:envSaved = @{}
    foreach ($k in $script:envKeys) { $script:envSaved[$k] = [Environment]::GetEnvironmentVariable($k) }

    $script:fakeHome = Join-Path $TestDrive 'home'
    $xdg = Join-Path $TestDrive 'xdg'
    New-Item -ItemType Directory -Path $script:fakeHome, $xdg | Out-Null
    $env:HOME = $script:fakeHome
    $env:XDG_CONFIG_HOME = Join-Path $xdg 'config'
    $env:XDG_DATA_HOME = Join-Path $xdg 'data'
    $env:XDG_STATE_HOME = Join-Path $xdg 'state'
    $env:XDG_CACHE_HOME = Join-Path $xdg 'cache'
    $env:GIT_CONFIG_GLOBAL = Join-Path $TestDrive 'empty.gitconfig'
    $env:GIT_CONFIG_NOSYSTEM = '1'
    $env:GIT_CEILING_DIRECTORIES = $TestDrive
    Remove-Item Env:NVIM_PROFILE -ErrorAction SilentlyContinue
    Set-Content -LiteralPath $env:GIT_CONFIG_GLOBAL -Value ''

    # Git repo fixture on an explicit branch with one commit.
    $script:repo = Join-Path $script:fakeHome 'repo'
    New-Item -ItemType Directory -Path (Join-Path $script:repo 'sub') | Out-Null
    [IO.File]::WriteAllText((Join-Path $script:repo 'README.md'), "readme`n")
    [IO.File]::WriteAllText((Join-Path $script:repo 'sub' 'inner.txt'), "inner`n")
    $script:longName = 'a-very-long-file-name-used-to-force-truncation.txt'
    [IO.File]::WriteAllText((Join-Path $script:repo 'sub' $script:longName), "long`n")
    git -C $script:repo init -q -b main
    git -C $script:repo config user.name 'Test'
    git -C $script:repo config user.email 'test@example.com'
    git -C $script:repo add -A
    git -C $script:repo commit -q -m 'init'
    if ($LASTEXITCODE -ne 0) { throw "git commit in fixture repo '$script:repo' failed (exit $LASTEXITCODE)." }

    # Second git repo on another branch, for files opened from outside the working directory.
    $script:repo2 = Join-Path $script:fakeHome 'repo2'
    New-Item -ItemType Directory -Path $script:repo2 | Out-Null
    [IO.File]::WriteAllText((Join-Path $script:repo2 'other.txt'), "other`n")
    git -C $script:repo2 init -q -b other
    git -C $script:repo2 config user.name 'Test'
    git -C $script:repo2 config user.email 'test@example.com'
    git -C $script:repo2 add -A
    git -C $script:repo2 commit -q -m 'init'
    if ($LASTEXITCODE -ne 0) { throw "git commit in fixture repo '$script:repo2' failed (exit $LASTEXITCODE)." }

    # Non-git fixture with explicit line endings.
    $script:plain = Join-Path $script:fakeHome 'plain'
    New-Item -ItemType Directory -Path $script:plain | Out-Null
    [IO.File]::WriteAllText((Join-Path $script:plain 'unix.txt'), "a`nb`n")
    [IO.File]::WriteAllText((Join-Path $script:plain 'dos.txt'), "a`r`nb`r`n")
    [IO.File]::WriteAllText((Join-Path $script:plain '100%.txt'), "a`n")

    $script:caseIndex = 0

    # Runs one Lua case body in a fresh headless Neovim started in $Cwd. The body runs
    # after the module loads and must return a table of strings; helpers stl/wb/tl render
    # the statusline, winbar, and tabline. Returns the table as a PSCustomObject.
    function script:Invoke-NvimBars {
        param(
            [Parameter(Mandatory)][string]$Cwd,
            [Parameter(Mandatory)][string]$Body
        )
        $script:caseIndex++
        $scriptPath = Join-Path $TestDrive "case$($script:caseIndex).lua"
        $outPath = Join-Path $TestDrive "case$($script:caseIndex).json"
        $errPath = Join-Path $TestDrive "case$($script:caseIndex).err"
        $lua = @"
vim.opt.rtp:prepend([==[$script:nvimConfig]==])
vim.cmd.cd(vim.fn.fnameescape([==[$Cwd]==]))
require('config.statusline')
local api = vim.api
local function eval(opt, winid, width, extra)
  winid = winid or api.nvim_get_current_win()
  local value = api.nvim_get_option_value(opt, { win = winid })
  local opts = vim.tbl_extend('force', { winid = winid, maxwidth = width or 80 }, extra or {})
  return api.nvim_eval_statusline(value, opts).str
end
function stl(winid, width) return eval('statusline', winid, width) end
function wb(winid, width) return eval('winbar', winid, width, { use_winbar = true }) end
function tl(width)
  return api.nvim_eval_statusline(vim.o.tabline, { maxwidth = width or 80, use_tabline = true }).str
end
local result = (function()
$Body
end)()
local f = assert(io.open([==[$outPath]==], 'w'))
f:write(vim.json.encode(result))
f:close()
"@
        Set-Content -LiteralPath $scriptPath -Value $lua -Encoding utf8NoBOM
        & $script:nvim.Source --clean --headless -l $scriptPath 2> $errPath
        $stderr = Get-Content -LiteralPath $errPath -Raw
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outPath)) {
            throw "nvim exited $LASTEXITCODE for case script '$scriptPath'. stderr: $stderr"
        }
        return Get-Content -LiteralPath $outPath -Raw -Encoding utf8 | ConvertFrom-Json
    }
}

AfterAll {
    # git writes read-only object files; clear the flag so Pester can delete TestDrive on Windows.
    Get-ChildItem -LiteralPath $TestDrive -Recurse -Force -File | ForEach-Object { $_.Attributes = 'Normal' }
    foreach ($k in $script:envKeys) { [Environment]::SetEnvironmentVariable($k, $script:envSaved[$k]) }
}

Describe 'winbar' {
    It 'shows the ~-shortened working directory and the buffer index' {
        $r = Invoke-NvimBars -Cwd $script:repo -Body @'
vim.cmd.edit('README.md')
vim.cmd.edit('sub/inner.txt')
return { bar = wb(nil, 40) }
'@
        $r.bar | Should -BeExactly ' ~/repo                             2/2 '
    }

    It 'marks a window-local directory with [win] in that window only' {
        $r = Invoke-NvimBars -Cwd $script:repo -Body @'
vim.cmd.edit('README.md')
local other = vim.api.nvim_get_current_win()
vim.cmd.vsplit()
vim.cmd.lcd('sub')
return { lcd = wb(nil, 40), other = wb(other, 40) }
'@
        $r.lcd | Should -BeExactly ' ~/repo/sub [win]                   1/1 '
        $r.other | Should -BeExactly ' ~/repo                             1/1 '
    }

    It 'marks a tab directory with [tab]' {
        $r = Invoke-NvimBars -Cwd $script:repo -Body @'
vim.cmd.tcd('sub')
return { bar = wb(nil, 40) }
'@
        $r.bar | Should -BeExactly ' ~/repo/sub [tab]                   1/1 '
    }

    It 'shows -/N for an unlisted buffer' {
        $r = Invoke-NvimBars -Cwd $script:repo -Body @'
vim.cmd.edit('README.md')
vim.cmd.edit('sub/inner.txt')
vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
return { bar = wb(nil, 40) }
'@
        $r.bar | Should -BeExactly ' ~/repo                             -/2 '
    }
}

Describe 'statusline' {
    It 'shows mode, git branch from the async fallback, separator, and relative path in a repo' {
        $r = Invoke-NvimBars -Cwd $script:repo -Body @'
vim.cmd.edit('sub/inner.txt')
vim.wait(10000, function() return stl(nil, 60):find('main', 1, true) ~= nil end, 20)
return { bar = stl(nil, 60) }
'@
        $r.bar | Should -Match '^ N  main │ sub/inner\.txt +1:1 100% $'
        $r.bar.Length | Should -Be 60
    }

    It 'shows no branch or separator outside a git repository' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
vim.cmd.edit('unix.txt')
-- Absence is not observable, so give the async git lookup time to come back.
vim.wait(1000)
return { bar = stl(nil, 60) }
'@
        $r.bar | Should -Match '^ N  unix\.txt +1:1 50% $'
    }

    It 'shows gitsigns branch and non-zero diff counts when gitsigns has attached' {
        $r = Invoke-NvimBars -Cwd $script:repo -Body @'
vim.cmd.edit('README.md')
vim.b.gitsigns_status_dict = { head = 'feature', added = 1, changed = 2, removed = 0 }
return { bar = stl(nil, 60) }
'@
        $r.bar | Should -Match '^ N  feature \+1 ~2 │ README\.md '
    }

    It 'flags a modified buffer with [+] and a non-modifiable one with [RO]' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
vim.cmd.edit('unix.txt')
vim.api.nvim_buf_set_lines(0, 0, 1, false, { 'changed' })
local modified = stl(nil, 60)
vim.cmd.edit('dos.txt')
vim.bo.modifiable = false
return { modified = modified, locked = stl(nil, 60) }
'@
        $r.modified | Should -Match '^ N  unix\.txt \[\+\] '
        $r.locked | Should -Match '^ N  dos\.txt \[RO\] '
    }

    It 'shows CRLF for a dos file and nothing for a unix file' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
vim.cmd.edit('dos.txt')
local dos = stl(nil, 60)
vim.cmd.edit('unix.txt')
return { dos = dos, unix = stl(nil, 60) }
'@
        $r.dos | Should -Match '^ N  dos\.txt +CRLF 1:1 50% $'
        $r.unix | Should -Not -Match 'CRLF'
    }

    It 'shows diagnostic counts per severity' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
vim.cmd.edit('unix.txt')
local sev = vim.diagnostic.severity
vim.diagnostic.set(vim.api.nvim_create_namespace('test'), 0, {
  { lnum = 0, col = 0, severity = sev.ERROR, message = 'e' },
  { lnum = 1, col = 0, severity = sev.WARN, message = 'w1' },
  { lnum = 1, col = 0, severity = sev.WARN, message = 'w2' },
})
return { bar = stl(nil, 60) }
'@
        $r.bar | Should -Match ' E1 W2 1:1 50% $'
    }

    It 'shows a non-UTF-8 encoding' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
vim.cmd.edit('unix.txt')
vim.bo.fileencoding = 'latin1'
return { bar = stl(nil, 60) }
'@
        $r.bar | Should -Match ' latin1 1:1 50% $'
    }

    It 'shows the names of attached LSP clients' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
vim.cmd.edit('unix.txt')
-- In-process fake server: answers initialize, accepts every other message.
vim.lsp.start({
  name = 'fakels',
  cmd = function()
    return {
      request = function(method, _, callback)
        if method == 'initialize' then
          callback(nil, { capabilities = {} })
        end
        return true, 1
      end,
      notify = function() return true end,
      is_closing = function() return false end,
      terminate = function() end,
    }
  end,
})
vim.wait(5000, function() return stl(nil, 60):find('fakels', 1, true) ~= nil end, 20)
return { bar = stl(nil, 60) }
'@
        $r.bar | Should -Match ' fakels 1:1 50% $'
    }

    It 'shows a file outside the working directory with its full path' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
vim.cmd.edit(vim.fn.fnameescape(vim.fn.expand('~/repo/README.md')))
return { bar = stl(nil, 60) }
'@
        $r.bar | Should -Match '^ N  ~/repo/README\.md '
    }

    It 'renders a % in a file name literally' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
vim.cmd.edit(vim.fn.fnameescape('100%.txt'))
return { bar = stl(nil, 60) }
'@
        $r.bar | Should -Match '^ N  100%\.txt '
    }

    It 'truncates the file name first in a narrow window' {
        $r = Invoke-NvimBars -Cwd $script:repo -Body @'
vim.cmd.edit('sub/a-very-long-file-name-used-to-force-truncation.txt')
vim.wait(10000, function() return stl(nil, 30):find('main', 1, true) ~= nil end, 20)
return { bar = stl(nil, 30) }
'@
        $r.bar | Should -Match '^ N  main │ <.*\.txt 1:1 100% $'
        $r.bar.Length | Should -Be 30
    }

    It 'shows the branch of the repo that holds the file when it lies outside the working directory' {
        $r = Invoke-NvimBars -Cwd $script:repo -Body @'
vim.cmd.edit(vim.fn.fnameescape(vim.fn.expand('~/repo2/other.txt')))
vim.wait(10000, function() return stl(nil, 60):find('other │', 1, true) ~= nil end, 20)
return { bar = stl(nil, 60) }
'@
        $r.bar | Should -Match '^ N  other │ ~/repo2/other\.txt '
    }

    It 'drops a branch lookup that finished after the cache was cleared' {
        $r = Invoke-NvimBars -Cwd $script:repo -Body @'
local callbacks = {}
vim.system = function(_, _, on_exit) callbacks[#callbacks + 1] = on_exit end
vim.cmd.edit('README.md')
stl(nil, 60)
vim.cmd.doautocmd('FocusGained')
stl(nil, 60)
callbacks[2]({ code = 0, stdout = 'new\n' })
callbacks[1]({ code = 0, stdout = 'old\n' })
vim.wait(100)
return { bar = stl(nil, 60), lookups = #callbacks }
'@
        $r.lookups | Should -Be 2
        $r.bar | Should -Match '^ N  new │ README\.md '
    }

    It 'warns once and shows no branch when git is not on PATH' {
        $r = Invoke-NvimBars -Cwd $script:repo -Body @'
local messages = {}
vim.notify = function(msg, level) messages[#messages + 1] = { msg = msg, level = level } end
package.loaded['config.statusline'] = nil
vim.env.PATH = ''
require('config.statusline')
vim.cmd.edit('README.md')
local first = stl(nil, 60)
local second = stl(nil, 60)
vim.wait(200)
return { first = first, second = second, count = #messages,
  msg = messages[1] and messages[1].msg or '', warn = messages[1] and messages[1].level == vim.log.levels.WARN }
'@
        $r.first | Should -Match '^ N  README\.md '
        $r.second | Should -Match '^ N  README\.md '
        $r.count | Should -Be 1
        $r.msg | Should -Match 'git'
        $r.warn | Should -BeTrue
    }

    It 'shows a URI-style buffer name raw' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
local buf = vim.api.nvim_create_buf(true, true)
vim.api.nvim_buf_set_name(buf, 'oil:///srv/100%/dir/')
vim.api.nvim_set_current_buf(buf)
return { bar = stl(nil, 60) }
'@
        $r.bar | Should -Match '^ N  oil:///srv/100%/dir/ '
    }

    It 'shows a buffer named after the working directory by its path' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
local buf = vim.api.nvim_create_buf(true, true)
vim.api.nvim_buf_set_name(buf, vim.fn.getcwd())
-- Keep netrw (loaded by --clean) from replacing the directory buffer with a listing.
vim.o.eventignore = 'all'
vim.api.nvim_set_current_buf(buf)
return { bar = stl(nil, 60) }
'@
        $r.bar | Should -Match '^ N  ~/plain '
    }

    It 'shows a terminal buffer by its term:// name without [RO]' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
vim.cmd.terminal()
local bar = stl(nil, 80)
vim.fn.jobstop(vim.bo.channel)
return { bar = bar }
'@
        $r.bar | Should -Match '^ [NT]  term://'
        $r.bar | Should -Not -Match '\[RO\]'
    }

    It 'shows the mode block only in the current window and uses inactive highlights elsewhere' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
vim.cmd.edit('unix.txt')
vim.diagnostic.set(vim.api.nvim_create_namespace('test'), 0, {
  { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'e' },
})
local other = vim.api.nvim_get_current_win()
vim.cmd.split()
local function groups(win, opt)
  opt = opt or 'statusline'
  local value = vim.api.nvim_get_option_value(opt, { win = win })
  local res = vim.api.nvim_eval_statusline(value,
    { winid = win, maxwidth = 60, highlights = true, use_winbar = opt == 'winbar' })
  return table.concat(vim.tbl_map(function(h) return h.group end, res.highlights), ',')
end
return { active = stl(nil, 60), inactive = stl(other, 60), activeGroups = groups(0), inactiveGroups = groups(other),
  wbActive = groups(0, 'winbar'), wbInactive = groups(other, 'winbar') }
'@
        $r.active | Should -Match '^ N  unix\.txt '
        $r.inactive | Should -Match '^ unix\.txt '
        $r.activeGroups | Should -Match '(^|,)StlError(,|$)'
        $r.inactiveGroups | Should -Match '(^|,)StlNCError(,|$)'
        $r.wbActive | Should -Match '(^|,)WbCwd(,|$)'
        $r.wbInactive | Should -Match '(^|,)WbNCCwd(,|$)'
    }
}

Describe 'highlights' {
    # Neovim stacks a part's group on its bar's group (StatusLine, StatusLineNC, WinBar,
    # WinBarNC) and a bar's reverse also reverses the part. A part therefore sets only its
    # text colour: as fg on a plain bar, and as bg on a reverse bar.
    It 'sets one colour per bar part so it inherits the background of its bar' {
        $r = Invoke-NvimBars -Cwd $script:plain -Body @'
local set = vim.api.nvim_set_hl
set(0, 'Normal', { fg = 0x101010, bg = 0xf0f0f0 })
set(0, 'Function', { fg = 0x777777 })
set(0, 'Comment', { fg = 0x999999 })
set(0, 'Directory', { fg = 0x000088 })
set(0, 'StatusLine', { fg = 0x111111, bg = 0x222222, reverse = true })
set(0, 'StatusLineNC', { fg = 0x333333, bg = 0x444444 })
set(0, 'WinBar', { bold = true })
set(0, 'WinBarNC', { fg = 0x555555, bg = 0x666666, reverse = true })
vim.cmd.doautocmd('ColorScheme')
local function get(name)
  local h = vim.api.nvim_get_hl(0, { name = name })
  return { fg = h.fg or -1, bg = h.bg or -1 }
end
return { stl = get('StlDim'), stlnc = get('StlNCDim'), wb = get('WbCwd'), wbnc = get('WbNCCwd'),
  mode = get('StlModeN') }
'@
        $r.stl.fg | Should -Be -1
        $r.stl.bg | Should -Be 0x999999
        $r.stlnc.fg | Should -Be 0x999999
        $r.stlnc.bg | Should -Be -1
        $r.wb.fg | Should -Be 0x000088
        $r.wb.bg | Should -Be -1
        $r.wbnc.fg | Should -Be -1
        $r.wbnc.bg | Should -Be 0x000088
        # Under the reverse StatusLine the stored pair is swapped: drawn as Normal-bg text on Function fg.
        $r.mode.fg | Should -Be 0x777777
        $r.mode.bg | Should -Be 0xf0f0f0
    }
}

Describe 'tabline' {
    It 'numbers three tabs 01 02 03 with the active file name' {
        $r = Invoke-NvimBars -Cwd $script:repo -Body @'
vim.cmd.edit('README.md')
vim.cmd.tabedit('sub/inner.txt')
vim.cmd.tabnew()
return { bar = tl(60) }
'@
        $r.bar | Should -BeExactly ' 01 README.md  02 inner.txt  03 [No Name] '
    }
}
