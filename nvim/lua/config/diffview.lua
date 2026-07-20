if _G.user_config.profile == 'minimal' then
  return
end

local ok, diffview = pcall(require, 'diffview')
if not ok then
  return
end

diffview.setup({
  enhanced_diff_hl = true,
  view = {
    default = { layout = 'diff2_horizontal' },
    merge_tool = { layout = 'diff3_horizontal' },
  },
  file_panel = {
    listing_style = 'tree',
    win_config = { position = 'left', width = 35 },
  },
})

-- Resolve origin/HEAD so branch review works on main or master; fall back to origin/main.
local function default_base()
  local ref = vim.fn.systemlist({ 'git', 'symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD' })[1]
  if vim.v.shell_error == 0 and ref and ref ~= '' then
    return ref:gsub('^refs/remotes/', '')
  end
  return 'origin/main'
end

local map = vim.keymap.set
map('n', '<leader>gv', '<cmd>DiffviewOpen<CR>', { desc = 'Diffview: working tree' })
map('n', '<leader>gV', '<cmd>DiffviewClose<CR>', { desc = 'Diffview: close' })
map('n', '<leader>gm', function()
  vim.cmd('DiffviewOpen ' .. default_base() .. '...HEAD')
end, { desc = 'Diffview: review branch vs default' })
map('n', '<leader>gh', '<cmd>DiffviewFileHistory<CR>', { desc = 'Diffview: repo history' })
map('n', '<leader>gH', '<cmd>DiffviewFileHistory %<CR>', { desc = 'Diffview: current file history' })
