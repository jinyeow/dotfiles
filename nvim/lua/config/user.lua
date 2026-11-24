-- Machine-specific config — edit before first launch on each machine.
-- Profile can also be overridden per-session via the NVIM_PROFILE env var:
--   Linux/macOS: NVIM_PROFILE=minimal nvim
--   PowerShell:  $env:NVIM_PROFILE='minimal'; nvim

-- 'full'    — install and load all plugins (default)
-- 'minimal' — options/keymaps/autocmds only, no plugins, built-in colorscheme
local profile = vim.env.NVIM_PROFILE or 'full'

local function find_pwsh_bundle()
  -- Minimal profile loads no plugins/LSP, so skip the ~/.vscode/extensions glob
  -- entirely — it would otherwise scan the filesystem on every minimal startup.
  if profile == 'minimal' then
    return ''
  end
  local matches = vim.fn.glob(
    vim.fn.expand('~') .. '/.vscode/extensions/ms-vscode.powershell-*/modules/PowerShellEditorServices',
    false,
    true
  )
  -- Sort by parsed version descending. A lexical sort ranks '9' above '1', so
  -- 2025.9.0 would beat 2025.10.0 and silently pick an older PSES whenever VS
  -- Code leaves two versions side by side. Unparseable names fall back to
  -- lexical order so the comparator never errors.
  table.sort(matches, function(a, b)
    local va = a:match('powershell%-([^/\\]+)')
    local vb = b:match('powershell%-([^/\\]+)')
    local pa = va and vim.version.parse(va)
    local pb = vb and vim.version.parse(vb)
    if pa and pb then
      return vim.version.gt(pa, pb)
    end
    return a > b
  end)
  -- bundle_path must be the parent of the PowerShellEditorServices folder
  return matches[1] and vim.fn.fnamemodify(matches[1], ':h') or ''
end

-- The pwsh executable to start PowerShell Editor Services with. The MSIX build of
-- PowerShell (what winget installs since 7.7) puts only an app-execution-alias stub on
-- PATH. vim.fn.executable() and jobstart() reject that stub, but libuv can still start
-- it, so ask pwsh for the path of its real executable.
local pwsh_exe_cache ---@type string?
local function pwsh_exe()
  if pwsh_exe_cache then
    return pwsh_exe_cache
  end
  if vim.fn.executable('pwsh') == 1 then
    pwsh_exe_cache = 'pwsh'
    return pwsh_exe_cache
  end
  local argv = { 'pwsh', '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', '[Environment]::ProcessPath' }
  local res = vim.system(argv, { text = true }):wait(10000)
  if res.code ~= 0 then
    error(('pwsh_exe: `%s` failed (exit %d): %s'):format(table.concat(argv, ' '), res.code, vim.trim(res.stderr or '')))
  end
  local path = vim.trim(res.stdout or '')
  if vim.fn.executable(path) ~= 1 then
    error(('pwsh_exe: pwsh reported its path as %q, which is not executable'):format(path))
  end
  pwsh_exe_cache = path
  return pwsh_exe_cache
end

-- The PSES code formatting preset for an LSP root directory: 'OTBS' when the root is
-- one of the path prefixes in vim.g.pwsh_otbs_roots (set in the untracked lua/user.lua),
-- else 'Allman'. Matching ignores case and treats '\' and '/' the same.
local function normalize_root(path)
  return (path:gsub('\\', '/'):gsub('/+$', ''):lower())
end

local function pwsh_format_preset(root_dir)
  local root = normalize_root(root_dir)
  for _, prefix in ipairs(vim.g.pwsh_otbs_roots or {}) do
    local p = normalize_root(prefix)
    if root == p or root:sub(1, #p + 1) == p .. '/' then
      return 'OTBS'
    end
  end
  return 'Allman'
end

_G.user_config = {
  profile = profile,

  -- LSP tool path (full profile only; silently skipped when empty)
  pwsh_bundle_path = find_pwsh_bundle(),
  pwsh_exe = pwsh_exe,
  pwsh_format_preset = pwsh_format_preset,

  -- Sunrise/sunset hours used as fallback when OS dark-mode detection fails.
  -- Dark mode applies from sunset_hour until sunrise_hour the next morning.
  sunrise_hour = 6,
  sunset_hour = 18,
}
