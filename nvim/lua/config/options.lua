local opt = vim.opt

opt.number         = true
opt.relativenumber = true

opt.tabstop     = 4
opt.shiftwidth  = 4
opt.shiftround  = true  -- round indent to nearest multiple of shiftwidth
opt.expandtab   = true
opt.autoindent  = true
opt.smartindent = true
opt.joinspaces  = false -- J always inserts one space, not two after punctuation

opt.wrap        = false
opt.breakindent = true  -- visually indent wrapped lines to match the start of the line

opt.ignorecase = true
opt.smartcase  = true
opt.hlsearch   = true
opt.incsearch  = true

opt.termguicolors = true
opt.signcolumn    = 'yes'
opt.cursorline    = true
opt.scrolloff     = 8
opt.sidescrolloff = 8

opt.mouse    = 'a'
opt.undofile = true
opt.swapfile    = false
opt.backup      = false
opt.updatetime  = 250
opt.timeoutlen  = 300
opt.ttimeoutlen = 10

opt.splitright = true
opt.splitbelow = true

opt.completeopt = 'menu,menuone,noselect'
opt.backspace   = 'indent,eol,start'

opt.synmaxcol  = 240
opt.nrformats  = 'hex'   -- <C-a>/<C-x> increments decimal and hex only, not octal
opt.showmatch  = true    -- briefly flash matching bracket/paren on insertion
opt.wildmode   = 'list:longest,full'  -- Tab: fill to longest common prefix + list, then cycle

opt.list      = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '·', extends = '›', precedes = '‹' }

-- Fallback file exclusions for native :find / command-mode tab completion.
-- FZF ignores this (uses fd/rg), so this only matters on machines without FZF.
opt.wildignore = {
  '*.o', '*.obj', '*.pyc', '*.pyo', '*.class', '*.dll', '*.pdb',
  '*/.git/*', '*/.hg/*', '*/.svn/*',
  '*/node_modules/*', '*/dist/*', '*/build/*', '*/_build/*',
  'tags', '*.min.js', '*.min.css',
}

-- Clipboard: not set to unnamedplus — win32yank process overhead causes
-- perceptible delay on every d/c/x/y. Use "+y / "+p explicitly instead
-- (keymaps in keymaps.lua).

-- Netrw
vim.g.netrw_banner  = 0
vim.g.netrw_winsize = 25
