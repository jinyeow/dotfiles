require("core.functions")
require("core.mappings")

local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local g = vim.g
local opt = vim.opt

-- Remap leader and local leader to <Space>
api.nvim_set_keymap("", "<Space>", "<Nop>", { noremap = true, silent = true })

opt.autoread = true
opt.background = 'dark'
opt.breakindent = true                                 --Enable break indent
opt.clipboard = "unnamedplus"                          -- Access system clipboard
opt.completeopt = {'menuone', 'noinsert', 'noselect'}  -- completion options (for deoplete)
opt.cursorline = true                                  -- highlight current line
opt.encoding = "utf-8"
opt.expandtab = true                                   -- spaces instead of tabs
opt.hidden = true                                      -- enable background buffers
opt.hlsearch = true                                    --Set highlight on search
opt.ignorecase = true                                  -- ignore case in search
opt.joinspaces = false                                 -- no double spaces with join
opt.list = true                                        -- show some invisible characters
opt.maxmempattern = 1000                               -- for Riv
opt.mouse = "nv"                                       -- Enable mouse in normal and visual modes
opt.number = true                                      -- show line numbers
opt.relativenumber = true                              -- number relative to current line
opt.scrolloff = 4                                      -- lines of context
opt.shiftround = true                                  -- round indent
opt.shiftwidth = 2                                     -- size of indent
opt.sidescrolloff = 8                                  -- columns of context
opt.signcolumn = "yes"                                 -- Always show sign column
opt.smartcase = true                                   -- do not ignore case with capitals
opt.smartindent = true                                 -- insert indents automatically

opt.splitbelow = true                                  -- put new windows below current
opt.splitright = true                                  -- put new vertical splits to right
opt.swapfile = false                                   -- disable swap files
opt.termguicolors = true                               -- truecolor support
opt.undofile = true                                    --Save undo history
opt.updatetime = 250                                   --Decrease update time
opt.wildmode = {'list', 'longest'}                     -- command-line completion mode
opt.wrap = false                                       -- disable line wrap

cmd[[filetype plugin on]]
cmd[[autocmd FileType * setlocal formatoptions-=cro]]
cmd[[autocmd FocusGained * checktime]]
-- cmd[[colorscheme nightfox]]

-- Highlight on yank
cmd [[
  augroup YankHighlight
    autocmd!
    autocmd TextYankPost * silent! lua vim.highlight.on_yank()
  augroup end
]]
