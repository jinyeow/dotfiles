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
-- opt.termguicolors = true                               -- truecolor support
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

-- The below configuration taken/inspred by https://github.com/nvim-lua/kickstart.nvim/blob/master/init.lua
-- Install package manager
--    https://github.com/folke/lazy.nvim
--    `:help lazy.nvim.txt` for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

-- NOTE: Here is where you install your plugins.
--  You can configure plugins using the `config` key.
--
--  You can also configure plugins after the setup call,
--    as they will be available in your neovim runtime.
require('lazy').setup({
  -- NOTE: First, some plugins that don't require any configuration

  -- Git related plugins
  'tpope/vim-fugitive',
  'tpope/vim-rhubarb',

  -- Detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',

  -- NOTE: This is where your plugins related to LSP can be installed.
  --  The configuration is done below. Search for lspconfig to find it below.
  {
    -- LSP Configuration & Plugins
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs to stdpath for neovim
      { 'williamboman/mason.nvim', config = true },
      'williamboman/mason-lspconfig.nvim',

      -- Useful status updates for LSP
      -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
      { 'j-hui/fidget.nvim', tag = 'legacy', opts = {} },

      -- Additional lua configuration, makes nvim stuff amazing!
      'folke/neodev.nvim',
    },
  },

  {
    -- Adds git releated signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      -- See `:help gitsigns.txt`
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      on_attach = function(bufnr)
        vim.keymap.set('n', '<leader>gp', require('gitsigns').prev_hunk, { buffer = bufnr, desc = '[G]o to [P]revious Hunk' })
        vim.keymap.set('n', '<leader>gn', require('gitsigns').next_hunk, { buffer = bufnr, desc = '[G]o to [N]ext Hunk' })
        vim.keymap.set('n', '<leader>ph', require('gitsigns').preview_hunk, { buffer = bufnr, desc = '[P]review [H]unk' })
      end,
    },
  },

  {
    -- Catppuccin theme (https://github.com/catppuccin/nvim)
    'catppuccin/nvim',
    name = "catppuccin"
    priority = 1000,
    config = function()
      vim.cmd.colorscheme 'catppuccin' -- catppuccin-latte, catppuccin-frappe, catppuccin-macchiato, catppuccin-mocha
    end,
  },

  {
    -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    -- Enable `lukas-reineke/indent-blankline.nvim`
    -- See `:help indent_blankline.txt`
    opts = {
      char = '┊',
      show_trailing_blankline_indent = false,
    },
  },

  -- "gc" to comment visual regions/lines
  { 'numToStr/Comment.nvim', opts = {} },

  -- Fuzzy Finder (files, lsp, etc)
  { 'nvim-telescope/telescope.nvim', branch = '0.1.x', dependencies = { 'nvim-lua/plenary.nvim' } },

  -- Fuzzy Finder Algorithm which requires local dependencies to be built.
  -- Only load if `make` is available. Make sure you have the system
  -- requirements installed.
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    -- NOTE: If you are having trouble with this installation,
    --       refer to the README for telescope-fzf-native for more instructions.
    build = 'make',
    cond = function()
      return vim.fn.executable 'make' == 1
    end,
  },

  {
    -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
    build = ':TSUpdate',
  },

  -- NOTE: Next Step on Your Neovim Journey: Add/Configure additional "plugins" for kickstart
  --       These are some example plugins that I've included in the kickstart repository.
  --       Uncomment any of the lines below to enable them.
  -- require 'kickstart.plugins.autoformat',
  -- require 'kickstart.plugins.debug',

  -- NOTE: The import below can automatically add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --    You can use this folder to prevent any conflicts with this init.lua if you're interested in keeping
  --    up-to-date with whatever is in the kickstart repo.
  --    Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  --
  --    For additional information see: https://github.com/folke/lazy.nvim#-structuring-your-plugins
  -- { import = 'custom.plugins' },
}, {})
