-- Theme: pick a colorscheme from the OS dark/light preference. The OS query can
-- cost tens of ms (reg.exe on Windows) and ran synchronously on every startup;
-- it now runs off the startup path — the sunrise/sunset heuristic paints a theme
-- instantly, then the OS result re-applies a beat later only if it disagrees
-- (a brief one-frame flash is possible on the rare mismatch).

-- Synchronous, no-process heuristic used to paint a theme immediately.
local function fallback_theme()
  local hour = tonumber(os.date('%H'))
  local sunrise = _G.user_config.sunrise_hour
  local sunset = _G.user_config.sunset_hour
  return (hour >= sunset or hour < sunrise) and 'dark' or 'light'
end

-- Apply a resolved 'dark'/'light' theme: set background, then the colorscheme.
-- Minimal profile uses a built-in colorscheme; otherwise Catppuccin mocha/latte.
local function apply_theme(theme)
  vim.o.background = theme
  if _G.user_config.profile == 'minimal' then
    -- habamax (dark) and lunaperche (light) are modern built-ins added in Neovim 0.9
    vim.cmd.colorscheme(theme == 'dark' and 'habamax' or 'lunaperche')
    return
  end
  local cat_ok, catppuccin = pcall(require, 'catppuccin')
  if cat_ok then
    catppuccin.setup({
      flavour = theme == 'dark' and 'mocha' or 'latte',
      transparent_background = false,
      integrations = {
        treesitter = true,
        gitsigns = true,
        native_lsp = { enabled = true },
        aerial = true,
      },
    })
    vim.cmd.colorscheme('catppuccin')
  else
    vim.cmd.colorscheme(theme == 'dark' and 'habamax' or 'lunaperche')
  end
end

-- Query the OS dark/light preference asynchronously. Detection ladder:
-- Windows registry -> macOS defaults -> GNOME gsettings -> KDE. Invokes on_result
-- (scheduled on the main loop) with 'dark'/'light', or not at all if undetermined.
local function detect_os_theme_async(on_result)
  local resolve = function(theme)
    vim.schedule(function()
      on_result(theme)
    end)
  end
  local sysname = vim.uv.os_uname().sysname
  if sysname == 'Windows_NT' then
    -- AppsUseLightTheme: 0x0 = dark, 0x1 = light
    vim.system({
      'reg',
      'query',
      'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize',
      '/v',
      'AppsUseLightTheme',
    }, { text = true }, function(res)
      local out = res.stdout or ''
      if out:find('0x0') then
        resolve('dark')
      elseif out:find('0x1') then
        resolve('light')
      end
    end)
  elseif sysname == 'Darwin' then
    -- Key absent (exit 1) means light mode
    vim.system({ 'defaults', 'read', '-g', 'AppleInterfaceStyle' }, { text = true }, function(res)
      resolve((res.stdout or ''):find('Dark') and 'dark' or 'light')
    end)
  else
    -- GNOME, then KDE. Resolve which tools exist up front (on the main loop —
    -- vim.fn can't be called from a vim.system callback), then chain: if gsettings
    -- doesn't resolve a theme, fall through to KDE. vim.system raises on a missing
    -- binary, unlike the vim.fn.system this replaced (which set vim.v.shell_error).
    local has_gsettings = vim.fn.executable('gsettings') == 1
    local has_kde = vim.fn.executable('kreadconfig5') == 1
    local query_kde = function()
      if not has_kde then
        return
      end
      vim.system({ 'kreadconfig5', '--group', 'General', '--key', 'ColorScheme' }, { text = true }, function(res)
        if res.code == 0 then
          resolve((res.stdout or ''):lower():find('dark') and 'dark' or 'light')
        end
      end)
    end
    if has_gsettings then
      vim.system({ 'gsettings', 'get', 'org.gnome.desktop.interface', 'color-scheme' }, { text = true }, function(res)
        if res.code == 0 then
          resolve((res.stdout or ''):find('dark') and 'dark' or 'light')
        else
          query_kde()
        end
      end)
    else
      query_kde()
    end
  end
end

local current_theme = fallback_theme()
apply_theme(current_theme)

-- Refine off the startup path: swap only when the OS disagrees with the heuristic.
detect_os_theme_async(function(os_theme)
  if os_theme ~= current_theme then
    current_theme = os_theme
    apply_theme(os_theme)
  end
end)

-- Minimal profile: colorscheme is already applied above; skip plugin setup.
if _G.user_config.profile == 'minimal' then
  return
end

-- Render-markdown
local rm_ok, render_md = pcall(require, 'render-markdown')
if rm_ok then
  render_md.setup({
    file_types = { 'markdown' },
    render_modes = { 'n', 'v' },
    heading = { enabled = true },
    code = { enabled = true },
    bullet = { enabled = true },
    quote = { enabled = true },
  })
end

-- fzf-lua: 'fzf-vim' profile recreates :Files/:Rg/:Buffers/:Commands/:Lines
local fzf_ok, fzf_lua = pcall(require, 'fzf-lua')
if fzf_ok then
  fzf_lua.setup({
    'fzf-vim',
    oldfiles = { include_current_session = true },
    -- Default builtin previewer re-highlights (syntax + treesitter) on nearly every
    -- candidate change while typing (delay=20, syntax_delay=0) - felt as input lag on
    -- <leader>ff. Debounce the preview redraw instead of disabling it.
    winopts = { preview = { delay = 100 } },
  })
end

-- nvim-surround: ys{motion}{char} add, ds{char} delete, cs{old}{new} change
local surround_ok, surround = pcall(require, 'nvim-surround')
if surround_ok then
  surround.setup()
end

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
if ogs_ok then
  oil_git_status.setup()
end

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
