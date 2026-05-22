-- Detect OS dark/light mode. Falls back to sunrise/sunset hours from user_config.
-- Returns 'dark' or 'light'.
local function detect_theme()
  local uname = vim.uv.os_uname()
  local out

  if uname.sysname == 'Windows_NT' then
    -- AppsUseLightTheme: 0x0 = dark, 0x1 = light
    out = vim.fn.system({ 'reg', 'query',
      'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize',
      '/v', 'AppsUseLightTheme' })
    if out:find('0x0') then return 'dark' end
    if out:find('0x1') then return 'light' end

  elseif uname.sysname == 'Darwin' then
    -- Key absent (exit 1) means light mode
    out = vim.fn.system({ 'defaults', 'read', '-g', 'AppleInterfaceStyle' })
    if out:find('Dark') then return 'dark' end
    return 'light'

  else
    -- GNOME
    out = vim.fn.system({ 'gsettings', 'get', 'org.gnome.desktop.interface', 'color-scheme' })
    if vim.v.shell_error == 0 then
      return out:find('dark') and 'dark' or 'light'
    end
    -- KDE
    out = vim.fn.system({ 'kreadconfig5', '--group', 'General', '--key', 'ColorScheme' })
    if vim.v.shell_error == 0 then
      return out:lower():find('dark') and 'dark' or 'light'
    end
  end

  -- Sunrise/sunset fallback
  local hour    = tonumber(os.date('%H'))
  local sunrise = _G.user_config.sunrise_hour
  local sunset  = _G.user_config.sunset_hour
  return (hour >= sunset or hour < sunrise) and 'dark' or 'light'
end

local theme = detect_theme()
vim.o.background = theme

-- Minimal profile: use a built-in colorscheme and stop here
if _G.user_config.profile == 'minimal' then
  -- habamax (dark) and lunaperche (light) are modern built-ins added in Neovim 0.9
  vim.cmd.colorscheme(theme == 'dark' and 'habamax' or 'lunaperche')
  return
end

-- Catppuccin: mocha (dark) / latte (light)
require('catppuccin').setup({
  flavour = theme == 'dark' and 'mocha' or 'latte',
  transparent_background = false,
  integrations = {
    treesitter = true,
    gitsigns   = true,
    native_lsp = { enabled = true },
  },
})
vim.cmd.colorscheme('catppuccin')

-- Render-markdown
require('render-markdown').setup({
  file_types   = { 'markdown' },
  render_modes = { 'n', 'v' },
  heading      = { enabled = true },
  code         = { enabled = true },
  bullet       = { enabled = true },
  quote        = { enabled = true },
})

-- FZF
vim.g.fzf_layout = { window = { width = 0.9, height = 0.8 } }

-- Mini.surround
require('mini.surround').setup({
  mappings = {
    add            = 'sa',
    delete         = 'sd',
    find           = 'sf',
    find_left      = 'sF',
    highlight      = 'sh',
    replace        = 'sr',
    update_n_lines = 'sn',
  },
})
