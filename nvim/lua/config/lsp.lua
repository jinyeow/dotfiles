if _G.user_config.profile == 'minimal' then return end

local ss_ok, schemastore = pcall(require, 'schemastore')

-- Shared LSP keymaps, attached per buffer on LspAttach
-- Note: K, [d, ]d, grn, grr, gri, gra are Neovim 0.11 built-in defaults — not remapped here.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local map = function(keys, func, desc)
      vim.keymap.set('n', keys, func, { buffer = ev.buf, desc = desc })
    end
    map('gd',         vim.lsp.buf.definition,    'Go to definition')
    map('gD',         vim.lsp.buf.declaration,   'Go to declaration')
    map('gr',         vim.lsp.buf.references,    'Go to references')
    map('gi',         vim.lsp.buf.implementation,'Go to implementation')
    map('<leader>rn', vim.lsp.buf.rename,        'Rename symbol')
    map('<leader>ca', vim.lsp.buf.code_action,   'Code action')
    map('<leader>d',  vim.diagnostic.open_float, 'Show diagnostics')

    -- Enable native LSP completion (manual trigger: <C-x><C-o>)
    vim.lsp.completion.enable(true, ev.data.client_id, ev.buf, { autotrigger = false })
  end,
})

vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = '',
      [vim.diagnostic.severity.WARN]  = '',
      [vim.diagnostic.severity.HINT]  = '',
      [vim.diagnostic.severity.INFO]  = '',
    },
  },
  virtual_text     = { current_line = true },
  update_in_insert = false,
  underline        = true,
  severity_sort    = true,
  float = {
    border = 'rounded',
    source = true,
  },
})

-- JSON
vim.lsp.config('jsonls', {
  settings = {
    json = {
      schemas  = ss_ok and schemastore.json.schemas() or {},
      validate = { enable = true },
    },
  },
})
vim.lsp.enable('jsonls')

-- YAML
vim.lsp.config('yamlls', {
  settings = {
    yaml = {
      schemaStore = { enable = false, url = '' },
      schemas     = ss_ok and schemastore.yaml.schemas({
        select = { 'Azure Pipelines', 'docker-compose.yml' },
      }) or {},
      validate   = true,
      completion = true,
      hover      = true,
    },
  },
})
vim.lsp.enable('yamlls')

-- Azure Pipelines
vim.lsp.config('azure_pipelines_ls', {})
vim.lsp.enable('azure_pipelines_ls')

-- Markdown
vim.lsp.enable('marksman')

-- Bicep (only if path is set)
if _G.user_config.bicep_lsp_path ~= '' then
  vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
    pattern  = '*.bicep',
    callback = function() vim.bo.filetype = 'bicep' end,
  })
  vim.lsp.config('bicep', {
    cmd       = { 'dotnet', _G.user_config.bicep_lsp_path },
    filetypes = { 'bicep' },
  })
  vim.lsp.enable('bicep')
end

-- PowerShell (only if bundle path is set)
if _G.user_config.pwsh_bundle_path ~= '' then
  vim.lsp.config('powershell_es', {
    bundle_path = _G.user_config.pwsh_bundle_path,
    shell       = 'pwsh',
  })
  vim.lsp.enable('powershell_es')
end
