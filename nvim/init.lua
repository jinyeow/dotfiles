require('config.performance')
require('config.user')
-- Untracked per-machine settings (gitignored), such as vim.g.pwsh_otbs_roots.
if vim.uv.fs_stat(vim.fn.stdpath('config') .. '/lua/user.lua') then
  require('user')
end
require('config.plugins')
require('config.options')
require('config.keymaps')
require('config.autocmds')
require('config.treesitter')
require('config.autopairs')
require('config.orgmode')
require('config.lsp')
require('config.dap')
require('config.gitsigns')
require('config.diffview')
require('config.ui')
require('config.statusline')
