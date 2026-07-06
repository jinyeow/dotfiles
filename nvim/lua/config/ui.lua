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
local cat_ok, catppuccin = pcall(require, 'catppuccin')
if cat_ok then
  catppuccin.setup({
    flavour = theme == 'dark' and 'mocha' or 'latte',
    transparent_background = false,
    integrations = {
      treesitter = true,
      gitsigns   = true,
      native_lsp = { enabled = true },
      aerial     = true,
    },
  })
  vim.cmd.colorscheme('catppuccin')
else
  vim.cmd.colorscheme(theme == 'dark' and 'habamax' or 'lunaperche')
end

-- Render-markdown
local rm_ok, render_md = pcall(require, 'render-markdown')
if rm_ok then
  render_md.setup({
    file_types   = { 'markdown' },
    render_modes = { 'n', 'v' },
    heading      = { enabled = true },
    code         = { enabled = true },
    bullet       = { enabled = true },
    quote        = { enabled = true },
  })
end

-- fzf-lua: 'fzf-vim' profile recreates :Files/:Rg/:Buffers/:Commands/:Lines
local fzf_ok, fzf_lua = pcall(require, 'fzf-lua')
if fzf_ok then fzf_lua.setup({ 'fzf-vim', oldfiles = { include_current_session = true } }) end

-- nvim-surround: ys{motion}{char} add, ds{char} delete, cs{old}{new} change
local surround_ok, surround = pcall(require, 'nvim-surround')
if surround_ok then surround.setup() end

-- oil.nvim: edit the filesystem like a buffer; replaces netrw
local oil_ok, oil = pcall(require, 'oil')
if oil_ok then
  oil.setup({
    default_file_explorer = true,
    view_options = { show_hidden = true },
    -- yes:2 reserves the two sign columns oil-git-status draws into
    win_options = { signcolumn = 'yes:2' },
  })
end

-- oil-git-status: per-file git status in oil's sign columns (left = index, right = working tree)
local ogs_ok, oil_git_status = pcall(require, 'oil-git-status')
if ogs_ok then oil_git_status.setup() end

-- aerial.nvim: code outline sidebar + symbol navigation
local aerial_ok, aerial = pcall(require, 'aerial')
if aerial_ok then
  aerial.setup({
    on_attach = function(bufnr)
      vim.keymap.set('n', '{', '<cmd>AerialPrev<CR>', { buffer = bufnr })
      vim.keymap.set('n', '}', '<cmd>AerialNext<CR>', { buffer = bufnr })
    end,
    post_parse_symbol = function(bufnr, item, _ctx)
      if vim.bo[bufnr].filetype == 'ps1' then
        item.name = item.name:gsub('^[Ff]unction%s+', '')
      end
      return item
    end,
  })
end
