-- Buffer-local PowerShell debug keymaps. Loaded only when a .ps1 buffer opens,
-- so this adds zero startup cost and no global keymaps (same pattern as cs.lua).
-- The `ps1` adapter/configs are wired in config/dap.lua; these just drive it.
-- Avoids the <leader>d / <leader>r prefixes (taken by LSP maps in lsp.lua) so
-- there is no which-key timeout clash — breakpoints go under <leader>b, and
-- stepping uses the conventional function keys.
local ok, dap = pcall(require, 'dap')
if not ok then
  return
end

local map = function(lhs, rhs, desc)
  vim.keymap.set('n', lhs, rhs, { buffer = true, desc = desc })
end

map('<F5>', dap.continue, 'Debug: start / continue')
map('<F10>', dap.step_over, 'Debug: step over')
map('<F11>', dap.step_into, 'Debug: step into')
map('<S-F11>', dap.step_out, 'Debug: step out')
map('<S-F5>', dap.terminate, 'Debug: terminate')

map('<leader>b', dap.toggle_breakpoint, 'Debug: toggle breakpoint')
map('<leader>B', function()
  dap.set_breakpoint(vim.fn.input('Breakpoint condition: '))
end, 'Debug: conditional breakpoint')
map('<leader>nr', dap.repl.toggle, 'Debug: toggle REPL')

-- Inspect state without a UI plugin: nvim-dap's built-in float shows the value
-- of the expression under the cursor (normal) or the visual selection (visual).
vim.keymap.set({ 'n', 'x' }, '<leader>e', function()
  require('dap.ui.widgets').hover()
end, { buffer = true, desc = 'Debug: evaluate under cursor' })
