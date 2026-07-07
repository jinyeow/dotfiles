-- Machine-specific config — edit before first launch on each machine.
-- Profile can also be overridden per-session via the NVIM_PROFILE env var:
--   Linux/macOS: NVIM_PROFILE=minimal nvim
--   PowerShell:  $env:NVIM_PROFILE='minimal'; nvim

local function find_pwsh_bundle()
  local matches = vim.fn.glob(
    vim.fn.expand('~') .. '/.vscode/extensions/ms-vscode.powershell-*/modules/PowerShellEditorServices',
    false,
    true
  )
  table.sort(matches, function(a, b)
    return a > b
  end)
  -- bundle_path must be the parent of the PowerShellEditorServices folder
  return matches[1] and vim.fn.fnamemodify(matches[1], ':h') or ''
end

_G.user_config = {
  -- 'full'    — install and load all plugins (default)
  -- 'minimal' — options/keymaps/autocmds only, no plugins, built-in colorscheme
  profile = vim.env.NVIM_PROFILE or 'full',

  -- LSP tool paths (full profile only; silently skipped when empty)
  bicep_lsp_path = '', -- e.g. 'C:/tools/bicep-langserver/Bicep.LangServer.dll'
  pwsh_bundle_path = find_pwsh_bundle(),

  -- Sunrise/sunset hours used as fallback when OS dark-mode detection fails.
  -- Dark mode applies from sunset_hour until sunrise_hour the next morning.
  sunrise_hour = 6,
  sunset_hour = 18,
}
