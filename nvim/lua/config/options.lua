local opt = vim.opt

opt.number         = true
opt.relativenumber = true

opt.tabstop     = 4
opt.shiftwidth  = 4
opt.expandtab   = true
opt.autoindent  = true
opt.smartindent = true

opt.wrap = false

opt.ignorecase = true
opt.smartcase  = true
opt.hlsearch   = true
opt.incsearch  = true

opt.termguicolors = true
opt.background    = 'dark'
opt.signcolumn    = 'yes'
opt.cursorline    = true
opt.scrolloff     = 8
opt.sidescrolloff = 8

opt.mouse       = 'a'
opt.clipboard   = 'unnamedplus'
opt.undofile    = true
opt.swapfile    = false
opt.backup      = false
opt.updatetime  = 250
opt.timeoutlen  = 300

opt.splitright = true
opt.splitbelow = true

opt.completeopt = 'menu,menuone,noselect'
opt.backspace   = 'indent,eol,start'

opt.lazyredraw = true
opt.synmaxcol  = 240

-- Fallback file exclusions for native :find / command-mode tab completion.
-- FZF ignores this (uses fd/rg), so this only matters on machines without FZF.
opt.wildignore = {
  '*.o', '*.obj', '*.pyc', '*.pyo', '*.class', '*.dll', '*.pdb',
  '*/.git/*', '*/.hg/*', '*/.svn/*',
  '*/node_modules/*', '*/dist/*', '*/build/*', '*/_build/*',
  'tags', '*.min.js', '*.min.css',
}

-- Netrw
vim.g.netrw_banner  = 0
vim.g.netrw_winsize = 25
