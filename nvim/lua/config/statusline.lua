-- Native statusline, winbar, and tabline. The options are '%!' expressions that call
-- the render functions on this module table. Neovim evaluates '%!' with the *current*
-- window still current, so per-window data is read from g:statusline_winid.

local M = {}
local api = vim.api
local group = api.nvim_create_augroup('config.statusline', { clear = true })

-- Double '%' so user-controlled text renders literally inside a statusline string.
local function esc(text)
  return (text:gsub('%%', '%%%%'))
end

-- The window being drawn (falls back to the current window outside a redraw).
local function drawn_win()
  local win = vim.g.statusline_winid
  if win and api.nvim_win_is_valid(win) then
    return win
  end
  return api.nvim_get_current_win()
end

-- Mode key (first char of nvim_get_mode().mode) -> { initial, colour source group }.
local modes = {
  n = { 'N', 'Function' },
  i = { 'I', 'String' },
  v = { 'V', 'Statement' },
  V = { 'V', 'Statement' },
  ['\22'] = { 'V', 'Statement' },
  R = { 'R', 'DiagnosticError' },
  c = { 'C', 'DiagnosticWarn' },
  t = { 'T', 'Type' },
  s = { 'S', 'Statement' },
  S = { 'S', 'Statement' },
  ['\19'] = { 'S', 'Statement' },
}

-- Group prefix per bar and window state -> the built-in group that fills that bar.
-- Neovim stacks each part's group on top of its bar's group, so a part sets one colour
-- and inherits the rest, including the bar's background. A bar with `reverse` also
-- reverses its parts, so there a part sets the background, which shows as its text.
-- Each part has one group per prefix (StlDim, StlNCDim, WbDim, WbNCDim, ...) because
-- the bars can differ in `reverse`.
local bars = { Stl = 'StatusLine', StlNC = 'StatusLineNC', Wb = 'WinBar', WbNC = 'WinBarNC' }

-- Highlight groups derived from the live colorscheme; re-applied on ColorScheme.
local function set_highlights()
  local function hl(name)
    return api.nvim_get_hl(0, { name = name, link = false })
  end
  local normal = hl('Normal')
  local reversed = hl('StatusLine').reverse
  for _, mode in pairs(modes) do
    local fg, bg = normal.bg, hl(mode[2]).fg
    if reversed then
      fg, bg = bg, fg
    end
    api.nvim_set_hl(0, 'StlMode' .. mode[1], { fg = fg, bg = bg, bold = true })
  end
  local parts = {
    Dim = 'Comment',
    Branch = 'String',
    Cwd = 'Directory',
    Marker = 'Special',
    Flag = 'WarningMsg',
    Error = 'DiagnosticError',
    Warn = 'DiagnosticWarn',
    Info = 'DiagnosticInfo',
    Hint = 'DiagnosticHint',
  }
  for prefix, base in pairs(bars) do
    local key = hl(base).reverse and 'bg' or 'fg'
    for part, source in pairs(parts) do
      api.nvim_set_hl(0, prefix .. part, { [key] = hl(source).fg })
    end
  end
end

-- Group prefix for the drawn window: the active or the inactive variant of a bar.
local function prefix(bar, win)
  return win == api.nvim_get_current_win() and bar or bar .. 'NC'
end

local has_git = vim.fn.executable('git') == 1
local warned_no_git = false

-- Branch per directory from an async `git -C <dir> rev-parse`; false = not a repo,
-- true = lookup in flight. DirChanged and FocusGained clear the cache and bump the
-- generation, so a callback started before the clear drops its result.
local branch_cache = {}
local generation = 0
local function fallback_branch(dir)
  if not has_git then
    if not warned_no_git then
      warned_no_git = true
      -- Deferred because this runs inside a redraw.
      vim.schedule(function()
        vim.notify('statusline: git is not on PATH, so the branch is unavailable', vim.log.levels.WARN)
      end)
    end
    return nil
  end
  local cached = branch_cache[dir]
  if cached == nil then
    branch_cache[dir] = true
    local started = generation
    local cmd = { 'git', '-C', dir, 'rev-parse', '--abbrev-ref', 'HEAD' }
    vim.system(cmd, { text = true }, function(res)
      vim.schedule(function()
        if started ~= generation then
          return
        end
        branch_cache[dir] = res.code == 0 and vim.trim(res.stdout or '') or false
        vim.cmd.redrawstatus({ bang = true })
      end)
    end)
    return nil
  end
  return type(cached) == 'string' and cached ~= '' and cached or nil
end

-- URI-style buffer names (oil://, term://, fugitive://) are shown as they are.
local function is_uri(name)
  return name:match('^%a[%w+.-]*://') ~= nil
end

-- Directory for the fallback branch: the file's directory for a normal file buffer,
-- else the drawn window's working directory.
local function git_dir(buf, cwd)
  local name = api.nvim_buf_get_name(buf)
  if vim.bo[buf].buftype == '' and name ~= '' and not is_uri(name) then
    return vim.fs.dirname(name)
  end
  return cwd
end

-- " main +1 ~2 │ " from gitsigns when attached, else the cached fallback branch.
local function git_part(buf, cwd, p)
  local status = vim.b[buf].gitsigns_status_dict
  local branch, counts = nil, {}
  if status and status.head and status.head ~= '' then
    branch = status.head
    for _, item in ipairs({ { '+', status.added }, { '~', status.changed }, { '-', status.removed } }) do
      if (item[2] or 0) > 0 then
        counts[#counts + 1] = item[1] .. item[2]
      end
    end
  else
    branch = fallback_branch(git_dir(buf, cwd))
  end
  if not branch then
    return ''
  end
  local diff = #counts > 0 and ' %#' .. p .. 'Dim#' .. table.concat(counts, ' ') or ''
  return '%#' .. p .. 'Branch#' .. esc(branch) .. diff .. ' %#' .. p .. 'Dim#│%* '
end

-- Buffer path relative to the drawn window's directory. A file outside that directory,
-- or a buffer named after the directory itself, shows its full path. URI-style names
-- render raw.
local function file_part(buf, cwd)
  local name = api.nvim_buf_get_name(buf)
  if name == '' then
    return '[No Name]'
  end
  if is_uri(name) then
    return esc(name)
  end
  local path = vim.fs.relpath(cwd, name)
  if not path or path == '.' then
    path = vim.fn.fnamemodify(name, ':~'):gsub('\\', '/')
  end
  return esc(path)
end

-- LSP client names per buffer, refreshed on LspAttach/LspDetach.
local lsp_cache = {}

local severities = {
  { vim.diagnostic.severity.ERROR, 'E', 'Error' },
  { vim.diagnostic.severity.WARN, 'W', 'Warn' },
  { vim.diagnostic.severity.INFO, 'I', 'Info' },
  { vim.diagnostic.severity.HINT, 'H', 'Hint' },
}

function M.statusline()
  local win = drawn_win()
  local buf = api.nvim_win_get_buf(win)
  local cwd = vim.fn.getcwd(win)
  local p = prefix('Stl', win)

  -- The mode block shows only in the current window; other windows start with a space.
  local mode_part = ' '
  if p == 'Stl' then
    local mode = modes[api.nvim_get_mode().mode:sub(1, 1)] or modes.n
    mode_part = '%#StlMode' .. mode[1] .. '# ' .. mode[1] .. ' %* '
  end

  local flags = {}
  if vim.bo[buf].modified then
    flags[#flags + 1] = '[+]'
  end
  -- 'nomodifiable' marks [RO] only for normal buffers; terminals are never modifiable.
  if vim.bo[buf].readonly or (not vim.bo[buf].modifiable and vim.bo[buf].buftype == '') then
    flags[#flags + 1] = '[RO]'
  end

  local right = {}
  local counts = vim.diagnostic.count(buf)
  for _, s in ipairs(severities) do
    if (counts[s[1]] or 0) > 0 then
      right[#right + 1] = '%#' .. p .. s[3] .. '#' .. s[2] .. counts[s[1]]
    end
  end
  if lsp_cache[buf] and lsp_cache[buf] ~= '' then
    right[#right + 1] = '%#' .. p .. 'Dim#' .. esc(lsp_cache[buf])
  end
  if vim.bo[buf].fileformat == 'dos' then
    right[#right + 1] = '%#' .. p .. 'Dim#CRLF'
  end
  local fenc = vim.bo[buf].fileencoding
  if fenc ~= '' and fenc ~= 'utf-8' then
    right[#right + 1] = '%#' .. p .. 'Dim#' .. esc(fenc)
  end
  right[#right + 1] = '%*%l:%c %p%% '

  return table.concat({
    mode_part,
    git_part(buf, cwd, p),
    '%<',
    file_part(buf, cwd),
    #flags > 0 and ' %#' .. p .. 'Flag#' .. table.concat(flags, ' ') .. '%*' or '',
    -- The leading space keeps the right group apart from a truncated file name.
    '%= ',
    table.concat(right, ' '),
  })
end

function M.winbar()
  local win = drawn_win()
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(win), ':~'):gsub('\\', '/')
  local p = prefix('Wb', win)
  local marker = ''
  if vim.fn.haslocaldir(win) == 1 then
    marker = ' %#' .. p .. 'Marker#[win]'
  elseif vim.fn.haslocaldir(-1, 0) == 1 then
    marker = ' %#' .. p .. 'Marker#[tab]'
  end

  -- Listed buffers ordered by number, computed per render.
  local bufs = vim.tbl_filter(function(buf)
    return vim.bo[buf].buflisted
  end, api.nvim_list_bufs())
  local current = api.nvim_win_get_buf(win)
  local index = '-'
  for i, buf in ipairs(bufs) do
    if buf == current then
      index = tostring(i)
      break
    end
  end

  return table.concat({
    '%#' .. p .. 'Cwd# ',
    esc(cwd),
    marker,
    '%*%=%#' .. p .. 'Dim#',
    index,
    '/',
    tostring(#bufs),
    ' %*',
  })
end

-- One clickable label per tab: zero-padded tab number and the active window's file.
function M.tabline()
  local current = api.nvim_get_current_tabpage()
  local labels = {}
  for i, tab in ipairs(api.nvim_list_tabpages()) do
    local name = api.nvim_buf_get_name(api.nvim_win_get_buf(api.nvim_tabpage_get_win(tab)))
    name = name == '' and '[No Name]' or vim.fn.fnamemodify(name, ':t')
    labels[#labels + 1] = table.concat({
      '%',
      tostring(i),
      'T',
      tab == current and '%#TabLineSel#' or '%#TabLine#',
      string.format(' %02d %s ', i, esc(name)),
    })
  end
  return table.concat(labels) .. '%#TabLineFill#%T'
end

set_highlights()
vim.o.laststatus = 2
vim.o.tabline = "%!v:lua.require'config.statusline'.tabline()"
vim.o.statusline = "%!v:lua.require'config.statusline'.statusline()"
vim.o.winbar = "%!v:lua.require'config.statusline'.winbar()"

local function redraw()
  vim.cmd.redrawstatus({ bang = true })
end

api.nvim_create_autocmd('ColorScheme', { group = group, callback = set_highlights })
-- The mode block is drawn only in the current window.
api.nvim_create_autocmd('ModeChanged', {
  group = group,
  callback = function()
    vim.cmd.redrawstatus()
  end,
})
api.nvim_create_autocmd('DiagnosticChanged', { group = group, callback = redraw })
-- Every winbar shows the listed-buffer count. BufDelete fires before the buffer is
-- unlisted, so redraw once it is.
api.nvim_create_autocmd({ 'BufAdd', 'BufDelete', 'BufWipeout' }, {
  group = group,
  callback = function()
    vim.schedule(redraw)
  end,
})
api.nvim_create_autocmd('OptionSet', { group = group, pattern = 'buflisted', callback = redraw })
api.nvim_create_autocmd('User', { group = group, pattern = 'GitSignsUpdate', callback = redraw })
api.nvim_create_autocmd({ 'DirChanged', 'FocusGained' }, {
  group = group,
  callback = function()
    branch_cache = {}
    generation = generation + 1
    redraw()
  end,
})

api.nvim_create_autocmd({ 'LspAttach', 'LspDetach' }, {
  group = group,
  callback = function(args)
    -- LspDetach fires before the client is removed: read the list once it is.
    vim.schedule(function()
      if not api.nvim_buf_is_valid(args.buf) then
        lsp_cache[args.buf] = nil
        return
      end
      local names = vim.tbl_map(function(client)
        return client.name
      end, vim.lsp.get_clients({ bufnr = args.buf }))
      lsp_cache[args.buf] = table.concat(names, ',')
      redraw()
    end)
  end,
})

return M
