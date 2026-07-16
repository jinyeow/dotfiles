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

_G.user_config = {
  profile = profile,

  -- LSP tool paths (full profile only; silently skipped when empty)
  bicep_lsp_path = '', -- e.g. 'C:/tools/bicep-langserver/Bicep.LangServer.dll'
  pwsh_bundle_path = find_pwsh_bundle(),

  -- Sunrise/sunset hours used as fallback when OS dark-mode detection fails.
  -- Dark mode applies from sunset_hour until sunrise_hour the next morning.
  sunrise_hour = 6,
  sunset_hour = 18,
}
