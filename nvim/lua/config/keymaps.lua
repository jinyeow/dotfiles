local map = vim.keymap.set

map('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Window navigation
map('n', '<C-h>', '<C-w>h')
map('n', '<C-j>', '<C-w>j')
map('n', '<C-k>', '<C-w>k')
map('n', '<C-l>', '<C-w>l')

-- Resize windows
map('n', '<C-Up>',    ':resize +2<CR>')
map('n', '<C-Down>',  ':resize -2<CR>')
map('n', '<C-Left>',  ':vertical resize -2<CR>')
map('n', '<C-Right>', ':vertical resize +2<CR>')

-- Buffer navigation
map('n', '<S-l>', ':bnext<CR>')
map('n', '<S-h>', ':bprevious<CR>')

-- Move selected lines
map('v', 'J', ":m '>+1<CR>gv=gv")
map('v', 'K', ":m '<-2<CR>gv=gv")

-- Stay in indent mode
map('v', '<', '<gv')
map('v', '>', '>gv')

-- Paste without overwriting register
map('v', 'p', '"_dP')

-- Centred scrolling
map('n', '<C-d>', '<C-d>zz')
map('n', '<C-u>', '<C-u>zz')
map('n', 'n',     'nzzzv')
map('n', 'N',     'Nzzzv')

-- File explorer / save / quit
map('n', '<leader>e', vim.cmd.Ex,   { desc = 'File explorer' })
map('n', '<leader>w', '<cmd>w<CR>', { desc = 'Save file' })
map('n', '<leader>q', '<cmd>q<CR>', { desc = 'Quit' })

-- Plugin keymaps: skipped in minimal profile (plugins not loaded)
if _G.user_config.profile ~= 'minimal' then
  -- FZF
  map('n', '<leader>ff', '<cmd>Files<CR>',    { desc = 'Find files' })
  map('n', '<leader>fg', '<cmd>Rg<CR>',       { desc = 'Find in files' })
  map('n', '<leader>fb', '<cmd>Buffers<CR>',  { desc = 'Find buffers' })
  map('n', '<leader>fh', '<cmd>Help<CR>',     { desc = 'Find help' })
  map('n', '<leader>fc', '<cmd>Commands<CR>', { desc = 'Find commands' })
  map('n', '<leader>fl', '<cmd>Lines<CR>',    { desc = 'Find lines' })

  -- Fugitive
  map('n', '<leader>gs', '<cmd>Git<CR>',        { desc = 'Git status' })
  map('n', '<leader>gc', '<cmd>Git commit<CR>', { desc = 'Git commit' })
  map('n', '<leader>gp', '<cmd>Git push<CR>',   { desc = 'Git push' })
  map('n', '<leader>gl', '<cmd>Git log<CR>',    { desc = 'Git log' })
  map('n', '<leader>gd', '<cmd>Gdiffsplit<CR>', { desc = 'Git diff' })
  map('n', '<leader>gb', '<cmd>Git blame<CR>',  { desc = 'Git blame' })
end
