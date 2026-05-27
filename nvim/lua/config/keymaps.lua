local map = vim.keymap.set

map('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Search: use very magic mode so +, (, | etc. work without escaping
map('n', '/', '/\\v')
map('v', '/', '/\\v')

-- Window / pane navigation — Ctrl+hjkl moves nvim windows first; at the edge
-- calls back to the multiplexer (zellij action move-focus / tmux select-pane).
-- Zellij pane navigation uses Alt+hjkl on the Zellij side (see zellij/config.kdl).
local function navigate(dir)
  local cur = vim.fn.winnr()
  vim.cmd('wincmd ' .. dir)
  if vim.fn.winnr() == cur then
    if vim.env.ZELLIJ then
      local zdirs = { h = 'left', j = 'down', k = 'up', l = 'right' }
      vim.fn.system('zellij action move-focus ' .. zdirs[dir])
    elseif vim.env.TMUX then
      local tdirs = { h = 'L', j = 'D', k = 'U', l = 'R' }
      vim.fn.system('tmux select-pane -' .. tdirs[dir])
    end
  end
end

if vim.env.ZELLIJ or vim.env.TMUX then
  map('n', '<C-h>', function() navigate('h') end, { silent = true })
  map('n', '<C-j>', function() navigate('j') end, { silent = true })
  map('n', '<C-k>', function() navigate('k') end, { silent = true })
  map('n', '<C-l>', function() navigate('l') end, { silent = true })
else
  map('n', '<C-h>', '<C-w>h')
  map('n', '<C-j>', '<C-w>j')
  map('n', '<C-k>', '<C-w>k')
  map('n', '<C-l>', '<C-w>l')
end

-- Resize windows
map('n', '<C-Up>',    ':resize +2<CR>')
map('n', '<C-Down>',  ':resize -2<CR>')
map('n', '<C-Left>',  ':vertical resize -2<CR>')
map('n', '<C-Right>', ':vertical resize +2<CR>')

-- Editing
map('n', '0',   '^')    -- 0 goes to first non-blank (^ is hard to reach)
-- Move selected lines
map('v', 'J', ":m '>+1<CR>gv=gv")
map('v', 'K', ":m '<-2<CR>gv=gv")

-- Stay in indent mode
map('v', '<', '<gv')
map('v', '>', '>gv')

-- Paste without overwriting register
map('v', 'p', '"_dP')

-- Explicit system clipboard access (clipboard is not set to unnamedplus)
map({'n', 'v'}, '<leader>y', '"+y', { desc = 'Yank to clipboard' })
map('n',        '<leader>Y', '"+Y', { desc = 'Yank line to clipboard' })
map({'n', 'v'}, '<leader>p', '"+p', { desc = 'Paste from clipboard' })

-- Centred scrolling
map('n', '<C-d>', '<C-d>zz')
map('n', '<C-u>', '<C-u>zz')
map('n', 'n',     'nzzzv')
map('n', 'N',     'Nzzzv')

-- File explorer: open oil in current file's directory; '-' inside oil goes up
map('n', '-', '<cmd>Oil<CR>', { desc = 'Open file explorer' })

-- Command-line
-- h expands to vert h only when typed as a standalone command
vim.cmd([[cabbrev <expr> h getcmdtype() == ':' && getcmdpos() == 2 ? 'vert h' : 'h']])
-- #!! in insert mode expands to #!/usr/bin/env <filetype>
vim.cmd([[inoreabbrev <expr> #!! "#!/usr/bin/env" . (empty(&filetype) ? '' : ' '.&filetype)]])

-- Plugin keymaps: skipped in minimal profile (plugins not loaded)
if _G.user_config.profile ~= 'minimal' then
  -- fzf-lua
  map('n', '<leader>ff', '<cmd>FzfLua files<CR>',             { desc = 'Find files' })
  map('n', '<leader>fg', '<cmd>FzfLua live_grep<CR>',         { desc = 'Find in files' })
  map('n', '<leader>fb', '<cmd>FzfLua buffers<CR>',           { desc = 'Find buffers' })
  map('n', '<leader>fc', '<cmd>FzfLua commands<CR>',          { desc = 'Find commands' })
  map('n', '<leader>fl', '<cmd>FzfLua lines<CR>',             { desc = 'Find lines' })
  map('n', '<leader>fs', '<cmd>FzfLua lsp_document_symbols<CR>',  { desc = 'Find symbols (file)' })
  map('n', '<leader>fS', '<cmd>FzfLua lsp_workspace_symbols<CR>', { desc = 'Find symbols (workspace)' })

  -- Aerial
  map('n', '<leader>a', '<cmd>AerialToggle<CR>', { desc = 'Toggle symbol outline' })

  -- Fugitive
  map('n', '<leader>gs', '<cmd>Git<CR>',        { desc = 'Git status' })
  map('n', '<leader>gc', '<cmd>Git commit<CR>', { desc = 'Git commit' })
  map('n', '<leader>gp', '<cmd>Git push<CR>',   { desc = 'Git push' })
  map('n', '<leader>gl', '<cmd>Git log<CR>',    { desc = 'Git log' })
  map('n', '<leader>gd', '<cmd>Gdiffsplit<CR>', { desc = 'Git diff' })
  map('n', '<leader>gb', '<cmd>Git blame<CR>',  { desc = 'Git blame' })
end
