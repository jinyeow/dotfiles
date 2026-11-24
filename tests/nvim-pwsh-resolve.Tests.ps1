#Requires -Version 7
# Pester tests for user_config.pwsh_exe() in nvim/lua/config/user.lua. Each case starts
# headless Neovim with --clean (no user config, no plugins), stubs vim.fn.executable and
# vim.system inside Neovim, loads only the user module from this repo, and asserts what
# pwsh_exe() returns or raises. No real pwsh process is started. The pwsh_format_preset
# cases use the same harness to check the PSES formatting preset chosen per LSP root.

BeforeAll {
    $script:nvim = Get-Command nvim -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $script:nvim)
    {
        throw 'nvim is not on PATH. Install Neovim 0.12+ to run tests/nvim-pwsh-resolve.Tests.ps1 (this suite never skips).'
    }
    $script:nvimConfig = Join-Path (Split-Path $PSScriptRoot -Parent) 'nvim'

    # Hermetic env: a fake HOME keeps user.lua's PSES bundle glob away from the real
    # ~/.vscode, and isolated XDG dirs keep Neovim off the real data and state dirs.
    $script:envKeys = @('HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME', 'NVIM_PROFILE')
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
    Remove-Item Env:NVIM_PROFILE -ErrorAction SilentlyContinue

    $script:caseIndex = 0

    # Runs one Lua case body in a fresh headless Neovim. Before the body runs, the
    # prelude installs the stubs and loads config.user:
    #   executable_map  name or path -> 0/1 that the vim.fn.executable stub returns
    #   system_result   { code, stdout, stderr } that the vim.system stub returns
    # The body must return a table; system_calls holds each argv passed to vim.system.
    # Returns the table as a PSCustomObject.
    function script:Invoke-PwshCase
    {
        param(
            [Parameter(Mandatory)][string]$Prelude,
            [Parameter(Mandatory)][string]$Body
        )
        $script:caseIndex++
        $scriptPath = Join-Path $TestDrive "case$($script:caseIndex).lua"
        $outPath = Join-Path $TestDrive "case$($script:caseIndex).json"
        $errPath = Join-Path $TestDrive "case$($script:caseIndex).err"
        $lua = @"
vim.opt.rtp:prepend([==[$script:nvimConfig]==])
$Prelude
system_calls = {}
local real_executable = vim.fn.executable
vim.fn.executable = function(name)
  if executable_map[name] ~= nil then
    return executable_map[name]
  end
  return real_executable(name)
end
vim.system = function(argv)
  system_calls[#system_calls + 1] = argv
  return { wait = function() return system_result end }
end
require('config.user')
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
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outPath))
        {
            throw "nvim exited $LASTEXITCODE for case script '$scriptPath'. stderr: $stderr"
        }
        return Get-Content -LiteralPath $outPath -Raw -Encoding utf8 | ConvertFrom-Json
    }
}

AfterAll {
    foreach ($k in $script:envKeys) { [Environment]::SetEnvironmentVariable($k, $script:envSaved[$k]) }
}

Describe 'user_config.pwsh_exe' {
    It 'returns pwsh without a lookup when pwsh passes executable()' {
        $r = Invoke-PwshCase -Prelude @'
executable_map = { pwsh = 1 }
system_result = { code = 0, stdout = '', stderr = '' }
'@ -Body @'
return { exe = _G.user_config.pwsh_exe(), calls = #system_calls }
'@
        $r.exe | Should -BeExactly 'pwsh'
        $r.calls | Should -Be 0
    }

    It 'asks pwsh for its real path when pwsh fails executable()' {
        $r = Invoke-PwshCase -Prelude @'
executable_map = { pwsh = 0, ['C:/Program Files/WindowsApps/PowerShell_7/pwsh.exe'] = 1 }
system_result = { code = 0, stdout = 'C:/Program Files/WindowsApps/PowerShell_7/pwsh.exe\r\n', stderr = '' }
'@ -Body @'
return { exe = _G.user_config.pwsh_exe(), argv = system_calls[1] }
'@
        $r.exe | Should -BeExactly 'C:/Program Files/WindowsApps/PowerShell_7/pwsh.exe'
        $r.argv[0] | Should -BeExactly 'pwsh'
        $r.argv[-1] | Should -BeExactly '[Environment]::ProcessPath'
    }

    It 'runs the lookup only once per session' {
        $r = Invoke-PwshCase -Prelude @'
executable_map = { pwsh = 0, ['C:/pwsh/pwsh.exe'] = 1 }
system_result = { code = 0, stdout = 'C:/pwsh/pwsh.exe', stderr = '' }
'@ -Body @'
local first = _G.user_config.pwsh_exe()
local second = _G.user_config.pwsh_exe()
return { first = first, second = second, calls = #system_calls }
'@
        $r.first | Should -BeExactly 'C:/pwsh/pwsh.exe'
        $r.second | Should -BeExactly 'C:/pwsh/pwsh.exe'
        $r.calls | Should -Be 1
    }

    It 'raises an error with the exit code and stderr when the lookup fails' {
        $r = Invoke-PwshCase -Prelude @'
executable_map = { pwsh = 0 }
system_result = { code = 1, stdout = '', stderr = 'boom' }
'@ -Body @'
local ok, err = pcall(_G.user_config.pwsh_exe)
return { ok = ok, err = tostring(err) }
'@
        $r.ok | Should -BeFalse
        $r.err | Should -Match 'exit 1'
        $r.err | Should -Match 'boom'
    }

    It 'raises an error when the reported path fails executable()' {
        $r = Invoke-PwshCase -Prelude @'
executable_map = { pwsh = 0, ['C:/gone/pwsh.exe'] = 0 }
system_result = { code = 0, stdout = 'C:/gone/pwsh.exe', stderr = '' }
'@ -Body @'
local ok, err = pcall(_G.user_config.pwsh_exe)
return { ok = ok, err = tostring(err) }
'@
        $r.ok | Should -BeFalse
        $r.err | Should -Match 'C:/gone/pwsh.exe'
    }
}

Describe 'user_config.pwsh_format_preset' {
    # Each case sets vim.g.pwsh_otbs_roots in the prelude (or leaves it unset) and asks
    # for the PSES formatting preset of one LSP root directory.
    It 'returns <Expected> for root <Root> with roots <Roots>' -ForEach @(
        @{ Roots = 'nil'; Root = 'E:/Personal/project'; Expected = 'Allman' }
        @{ Roots = "{ 'E:/WorkOrg' }"; Root = 'E:/Personal/project'; Expected = 'Allman' }
        @{ Roots = "{ 'E:/WorkOrg' }"; Root = 'E:/WorkOrg/repo'; Expected = 'OTBS' }
        @{ Roots = "{ 'E:/WorkOrg' }"; Root = 'E:/WorkOrg'; Expected = 'OTBS' }
        @{ Roots = "{ 'e:\\workorg\\' }"; Root = 'E:/WorkOrg/repo'; Expected = 'OTBS' }
        @{ Roots = "{ 'E:/WorkOrg/' }"; Root = 'e:\workorg\repo'; Expected = 'OTBS' }
        @{ Roots = "{ 'E:/WorkOrg' }"; Root = 'E:/WorkOrgOther/repo'; Expected = 'Allman' }
        @{ Roots = "{ 'D:/Other', 'E:/WorkOrg' }"; Root = 'E:/WorkOrg/repo'; Expected = 'OTBS' }
    ) {
        $r = Invoke-PwshCase -Prelude @"
executable_map = {}
vim.g.pwsh_otbs_roots = $Roots
"@ -Body @"
return { preset = _G.user_config.pwsh_format_preset([==[$Root]==]) }
"@
        $r.preset | Should -BeExactly $Expected
    }
}

Describe 'powershell_es before_init' {
    # Loads the real nvim/lua/config/lsp.lua with vim.lsp.config captured and every other
    # language server reported as not installed, then gives each of two roots its own
    # copy of the powershell_es config (as vim.lsp does for each client) and runs
    # before_init on it. Each copy must carry its own root's preset in its own table, in
    # the same settings table the client already holds.
    It 'sets the preset per client from its root without sharing settings' {
        $r = Invoke-PwshCase -Prelude @'
executable_map = { dotnet = 0, marksman = 0, ['lua-language-server'] = 0, ['bicep-ls'] = 0 }
vim.g.pwsh_otbs_roots = { 'E:/WorkOrg' }
'@ -Body @'
_G.user_config.pwsh_bundle_path = 'C:/fake/PowerShellEditorServices'
local captured = {}
vim.lsp.config = function(name, cfg) captured[name] = cfg end
vim.lsp.enable = function() end
require('config.lsp')
local base = assert(captured.powershell_es, 'powershell_es was not registered')
local personal = vim.deepcopy(base)
personal.root_dir = 'E:/Personal/project'
local work = vim.deepcopy(base)
work.root_dir = 'E:/WorkOrg/repo'
-- The client keeps these table references from creation and sends them to PSES, so
-- before_init must change them in place rather than replace config.settings.
local personal_sent = personal.settings
local work_sent = work.settings
base.before_init({}, personal)
base.before_init({}, work)
return {
  personal = personal_sent.powershell.codeFormatting.preset,
  work = work_sent.powershell.codeFormatting.preset,
  base = base.settings.powershell.codeFormatting.preset,
  shared = personal_sent == work_sent,
}
'@
        $r.personal | Should -BeExactly 'Allman'
        $r.work | Should -BeExactly 'OTBS'
        $r.base | Should -BeExactly 'Allman'
        $r.shared | Should -BeFalse
    }
}
