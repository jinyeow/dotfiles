-- Buffer-local C#/.NET helpers. Loaded only when a .cs buffer opens, so this
-- adds zero startup cost and no global keymaps. Testing/run/build shell out to
-- the dotnet CLI rather than pulling in a plugin (deliberate perf choice).
local map = function(lhs, cmd, desc)
  vim.keymap.set('n', lhs, cmd, { buffer = true, desc = desc })
end

map('<leader>nt', '<cmd>botright split | terminal dotnet test<cr>',  '.NET test')
map('<leader>nr', '<cmd>botright split | terminal dotnet run<cr>',   '.NET run')
map('<leader>nb', '<cmd>botright split | terminal dotnet build<cr>', '.NET build')

-- Inlay hints are off by default (no autocmd cost); toggle on demand.
map('<leader>th', function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
end, 'Toggle inlay hints')
