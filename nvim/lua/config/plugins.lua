vim.g.mapleader      = ' '
vim.g.maplocalleader = '\\'

if _G.user_config.profile == 'minimal' then return end

local specs = {
  'https://github.com/nvim-treesitter/nvim-treesitter',
  'https://github.com/nvim-treesitter/nvim-treesitter-textobjects',
  'https://github.com/junegunn/fzf',
  -- fzf-lua: Neovim-native fzf frontend. Uses the same fzf binary as the shell
  -- integration (rfv/frg in the PS profile). The 'fzf-vim' profile creates the
  -- same :Files/:Rg/:Buffers/:Commands/:Lines commands as fzf.vim did, so all
  -- keymaps are unchanged. Adds LSP pickers (definitions, references, diagnostics)
  -- that the old VimL fzf.vim could not provide.
  'https://github.com/ibhagwan/fzf-lua',
  'https://github.com/tpope/vim-fugitive',
  'https://github.com/kylechui/nvim-surround',
  'https://github.com/stevearc/oil.nvim',
  'https://github.com/stevearc/aerial.nvim',
  'https://github.com/catppuccin/nvim',
  'https://github.com/neovim/nvim-lspconfig',
  'https://github.com/b0o/schemastore.nvim',
  'https://github.com/lewis6991/gitsigns.nvim',
  'https://github.com/MeanderingProgrammer/render-markdown.nvim',
}

-- load=true: sources plugin/ and ftdetect/ files immediately so subsequent
-- config modules (treesitter, lsp, ui, gitsigns) can use the plugins.
-- confirm=false: installs silently on a fresh machine.
vim.pack.add(specs, { load = true, confirm = false })
