vim.g.mapleader      = ' '
vim.g.maplocalleader = '\\'

if _G.user_config.profile == 'minimal' then return end

local specs = {
  'https://github.com/nvim-treesitter/nvim-treesitter',
  'https://github.com/nvim-treesitter/nvim-treesitter-textobjects',
  'https://github.com/junegunn/fzf',
  'https://github.com/junegunn/fzf.vim',
  'https://github.com/tpope/vim-fugitive',
  'https://github.com/tpope/vim-commentary',
  'https://github.com/tpope/vim-repeat',
  'https://github.com/catppuccin/nvim',
  'https://github.com/echasnovski/mini.nvim',
  'https://github.com/neovim/nvim-lspconfig',
  'https://github.com/b0o/schemastore.nvim',
  'https://github.com/lewis6991/gitsigns.nvim',
  'https://github.com/MeanderingProgrammer/render-markdown.nvim',
}

-- zellij-nav.nvim: only install when the zellij binary is present.
if vim.fn.executable('zellij') == 1 then
  table.insert(specs, 'https://github.com/swaits/zellij-nav.nvim')
end

-- load=true: sources plugin/ and ftdetect/ files immediately so subsequent
-- config modules (treesitter, lsp, ui, gitsigns) can use the plugins.
-- confirm=false: installs silently on a fresh machine.
vim.pack.add(specs, { load = true, confirm = false })

-- zellij-nav.nvim setup: pcall guards the first launch before the plugin is installed.
if vim.fn.executable('zellij') == 1 then
  local ok, nav = pcall(require, 'zellij-nav')
  if ok then nav.setup() end
end
