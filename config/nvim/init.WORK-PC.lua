-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local opt = vim.opt

opt.number = true
opt.relativenumber = true

opt.splitbelow = true
opt.splitright = true

opt.autoindent = true
opt.expandtab = true
opt.shiftwidth = 0
opt.smartindent = true
opt.tabstop = 4

opt.wrap = false

opt.hlsearch = true
opt.ignorecase = true
opt.incsearch = true
opt.smartcase = true

opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8

opt.clipboard = 'unnamedplus'
opt.mouse = 'a'
opt.undofile = true
opt.swapfile = false
opt.backup = false
opt.updatetime = 250
opt.timeoutlen = 300

opt.completeopt = 'menu,menuone,noselect'
opt.backspace = 'indent,eol,start'

-- Key mappings
local keymap = vim.keymap

-- Clear search highlighting
keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Better window navigation
keymap.set('n', '<C-h>', '<C-w>h')
keymap.set('n', '<C-j>', '<C-w>j')
keymap.set('n', '<C-k>', '<C-w>k')
keymap.set('n', '<C-l>', '<C-w>l')

-- Buffer navigation
keymap.set('n', '<S-l>', ':bnext<CR>')
keymap.set('n', '<S-h>', ':bprevious<CR>')

-- Stay in indent mode
keymap.set('v', '<', '<gv')
keymap.set('v', '>', '>gv')

-- Better paste
keymap.set('v', 'p', '"_dP')

-- Keep cursor centered when scrolling
keymap.set('n', '<C-d>', '<C-d>zz')
keymap.set('n', '<C-u>', '<C-u>zz')
keymap.set('n', 'n', 'nzzzv')
keymap.set('n', 'N', 'Nzzzv')

-- File explorer
keymap.set('n', '<leader>e', vim.cmd.Ex, { desc = 'Open file explorer' })



-- Auto-commands
local autocmd = vim.api.nvim_create_autocmd

-- Highlight on yank
autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

-- Remove trailing whitespace on save
autocmd('BufWritePre', {
  pattern = '*',
  command = '%s/\\s\\+$//e',
})

-- Go to last location when opening a buffer
autocmd('BufReadPost', {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Netrw settings (built-in file explorer)
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 25

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
    { "nvim-treesitter/nvim-treesitter", branch = 'master', lazy = false, build = ":TSUpdate" },
    { "nvim-treesitter/nvim-treesitter-context", branch = 'master', lazy = false, build = ":TSUpdate" },
    { "ibhagwan/fzf-lua", opts = {} },
    { 'nvim-mini/mini.ai', version = false },
    { 'nvim-mini/mini.bracketed', version = false },
    { 'nvim-mini/mini.diff', version = false },
    { 'tpope/vim-fugitive', version = false, cmd = { 'Git', 'G' } }, -- Lazy-load Fugitive when these commands are used
    {
        "kylechui/nvim-surround",
        version = "^3.0.0", -- Use for stability; omit to use `main` branch for the latest features
        event = "VeryLazy",
        config = function()
            require("nvim-surround").setup({
                -- Configuration here, or leave empty to use defaults
            })
        end
    },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "catppuccin" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})

