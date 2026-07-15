vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

if _G.user_config.profile == 'minimal' then
  return
end

local specs = {
  -- Pinned to master: the main branch is a from-scratch rewrite that drops the
  -- configs.setup{} module framework this config relies on (repo archived 2026-04).
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'master' },
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects', version = 'master' },
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
  'https://github.com/refractalize/oil-git-status.nvim',
  'https://github.com/stevearc/aerial.nvim',
  'https://github.com/catppuccin/nvim',
  'https://github.com/neovim/nvim-lspconfig',
  'https://github.com/seblyng/roslyn.nvim',
  'https://github.com/b0o/schemastore.nvim',
  'https://github.com/lewis6991/gitsigns.nvim',
  'https://github.com/MeanderingProgrammer/render-markdown.nvim',
  -- orgmode compiles its own pinned tree-sitter-org grammar into its own plugin
  -- dir on setup(), independent of nvim-treesitter. Do NOT add 'org' to
  -- treesitter.lua's ensure_installed — two parser/org.so on the runtimepath make
  -- orgmode disown the parser and stop managing its version.
  'https://github.com/nvim-orgmode/orgmode',
  -- DAP client only. The PowerShell adapter (config/dap.lua) drives PowerShell
  -- Editor Services in -DebugServiceOnly mode over a named pipe — no debugger
  -- plugin needed, PSES *is* the debug server (same one VS Code uses).
  'https://github.com/mfussenegger/nvim-dap',
}

-- load=true: sources plugin/ and ftdetect/ files immediately so subsequent
-- config modules (treesitter, lsp, ui, gitsigns) can use the plugins.
-- confirm=false: installs silently on a fresh machine.
vim.pack.add(specs, { load = true, confirm = false })
