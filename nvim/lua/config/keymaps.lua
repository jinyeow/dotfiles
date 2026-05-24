local map = vim.keymap.set

map('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Search: use very magic mode so +, (, | etc. work without escaping
map('n', '/', '/\\v')
map('v', '/', '/\\v')

-- Window / pane navigation
-- Inside Zellij: Ctrl+hjkl moves between nvim windows, and at the edge jumps
-- to the adjacent Zellij pane (or tab for left/right) via the CLI.
-- Outside Zellij: fall back to standard <C-w> movement.
if vim.env.ZELLIJ and _G.user_config.profile ~= 'minimal' then
  map('n', '<C-h>', '<cmd>ZellijNavigateLeftTab<cr>',  { silent = true })
  map('n', '<C-j>', '<cmd>ZellijNavigateDown<cr>',     { silent = true })
  map('n', '<C-k>', '<cmd>ZellijNavigateUp<cr>',       { silent = true })
  map('n', '<C-l>', '<cmd>ZellijNavigateRightTab<cr>', { silent = true })
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

-- Buffer navigation
map('n', '<S-l>', ':bnext<CR>')
map('n', '<S-h>', ':bprevious<CR>')

-- Editing
map('n', 'Y',   'y$')   -- Y yanks to EOL, consistent with C and D
map('n', '0',   '^')    -- 0 goes to first non-blank (^ is hard to reach)
map('i', 'jj',  '<Esc>')

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

-- File explorer
map('n', '<C-S-e>', vim.cmd.Ex, { desc = 'File explorer' })

-- Command-line
-- h expands to vert h only when typed as a standalone command
vim.cmd([[cabbrev <expr> h getcmdtype() == ':' && getcmdpos() == 2 ? 'vert h' : 'h']])
-- #!! in insert mode expands to #!/usr/bin/env <filetype>
vim.cmd([[inoreabbrev <expr> #!! "#!/usr/bin/env" . (empty(&filetype) ? '' : ' '.&filetype)]])

-- Plugin keymaps: skipped in minimal profile (plugins not loaded)
if _G.user_config.profile ~= 'minimal' then
  -- FZF
  map('n', '<leader>ff', '<cmd>Files<CR>',    { desc = 'Find files' })
  map('n', '<leader>fg', '<cmd>Rg<CR>',       { desc = 'Find in files' })
  map('n', '<leader>fb', '<cmd>Buffers<CR>',  { desc = 'Find buffers' })
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
