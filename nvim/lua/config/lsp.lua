if _G.user_config.profile == 'minimal' then
  return
end

local ss_ok, schemastore = pcall(require, 'schemastore')

-- Shared LSP keymaps, attached per buffer on LspAttach
-- Note: K, [d, ]d, grn, grr, gri, gra are Neovim 0.11 built-in defaults — not remapped here.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local map = function(keys, func, desc)
      vim.keymap.set('n', keys, func, { buffer = ev.buf, desc = desc })
    end
    map('gd', vim.lsp.buf.definition, 'Go to definition')
    map('gD', vim.lsp.buf.declaration, 'Go to declaration')
    map('<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
    map('<leader>ca', vim.lsp.buf.code_action, 'Code action')
    map('<leader>d', vim.diagnostic.open_float, 'Show diagnostics')

    -- Enable native LSP completion (autotrigger: complete as you type)
    vim.lsp.completion.enable(true, ev.data.client_id, ev.buf, { autotrigger = true })

    local client = vim.lsp.get_client_by_id(ev.data.client_id)

    -- Highlight other references to the symbol under the cursor on CursorHold
    -- (updatetime = 250); cleared on move. Skipped for servers without the capability.
    if client and client:supports_method('textDocument/documentHighlight') then
      local hl = vim.api.nvim_create_augroup('lsp_doc_highlight_' .. ev.buf, { clear = true })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        group = hl,
        buffer = ev.buf,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        group = hl,
        buffer = ev.buf,
        callback = vim.lsp.buf.clear_references,
      })
    end

    -- Prime PowerShell workspace index once per client so cross-file gd works immediately
    if client and client.name == 'powershell_es' and not client._pwsh_indexed then
      client._pwsh_indexed = true
      vim.defer_fn(function()
        client:request('workspace/symbol', { query = '' }, function() end)
      end, 3000)
    end
  end,
})

vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = '',
      [vim.diagnostic.severity.WARN] = '',
      [vim.diagnostic.severity.HINT] = '',
      [vim.diagnostic.severity.INFO] = '',
    },
  },
  virtual_text = { current_line = true },
  update_in_insert = false,
  underline = true,
  severity_sort = true,
  float = {
    border = 'rounded',
    source = true,
  },
})

-- JSON
vim.lsp.config('jsonls', {
  settings = {
    json = {
      schemas = ss_ok and schemastore.json.schemas() or {},
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
      schemas = ss_ok and schemastore.yaml.schemas({
        select = { 'docker-compose.yml' },
      }) or {},
      validate = true,
      completion = true,
      hover = true,
    },
  },
})
vim.lsp.enable('yamlls')

-- Azure Pipelines — attach only to the dedicated `azure-pipelines` filetype (set
-- in autocmds.lua), not to every `yaml` buffer as the server's default would. The
-- schema glob still covers the on-disk `*.y*l` names so validation/completion work.
vim.lsp.config('azure_pipelines_ls', {
  filetypes = { 'azure-pipelines' },
  settings = {
    yaml = {
      schemas = {
        ['https://raw.githubusercontent.com/microsoft/azure-pipelines-vscode/master/service-schema.json'] = { '*.y*l' },
      },
    },
  },
})
vim.lsp.enable('azure_pipelines_ls')

-- Markdown (only if installed)
if vim.fn.executable('marksman') == 1 then
  vim.lsp.enable('marksman')
end

-- C# / .NET (Roslyn) — only when the dotnet SDK is available
if vim.fn.executable('dotnet') == 1 then
  require('roslyn').setup({}) -- registers + starts roslyn on the `cs` filetype
  vim.lsp.config('roslyn', {
    settings = {
      -- openFiles (not fullSolution) keeps background analysis cheap — perf-first
      ['csharp|background_analysis'] = { dotnet_analyzer_diagnostics_scope = 'openFiles' },
    },
  })
end

-- Bicep (only if path is set)
if _G.user_config.bicep_lsp_path ~= '' then
  vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
    pattern = '*.bicep',
    callback = function()
      vim.bo.filetype = 'bicep'
    end,
  })
  vim.lsp.config('bicep', {
    cmd = { 'dotnet', _G.user_config.bicep_lsp_path },
    filetypes = { 'bicep' },
  })
  vim.lsp.enable('bicep')
end

-- PowerShell (only if bundle path is set)
if _G.user_config.pwsh_bundle_path ~= '' then
  local _bundle = _G.user_config.pwsh_bundle_path
  local _temp = vim.fn.stdpath('cache')
  local _script = _bundle .. '/PowerShellEditorServices/Start-EditorServices.ps1'
  local _pwsh_cmd = ("& '%s' -BundledModulesPath '%s' -LogPath '%s/powershell_es.log' -SessionDetailsPath '%s/powershell_es.session.json' -FeatureFlags @() -AdditionalModules @() -HostName nvim -HostProfileId 0 -HostVersion 1.0.0 -Stdio -LogLevel Information"):format(
    _script,
    _bundle,
    _temp,
    _temp
  )

  vim.lsp.config('powershell_es', {
    cmd = { 'pwsh', '-NoLogo', '-NoProfile', '-Command', _pwsh_cmd },
    filetypes = { 'ps1' },
    root_dir = function(bufnr, cb)
      local fname = vim.api.nvim_buf_get_name(bufnr)
      local dir = vim.fn.fnamemodify(fname, ':h')
      local check = dir
      for _ = 1, 10 do
        local handle = vim.uv.fs_scandir(check)
        if handle then
          while true do
            local name, ftype = vim.uv.fs_scandir_next(handle)
            if not name then
              break
            end
            if (ftype == 'file' or ftype == 'link') and (name:match('%.psd1$') or name:match('%.psm1$')) then
              cb(check)
              return
            end
          end
        end
        local parent = vim.fn.fnamemodify(check, ':h')
        if parent == check then
          break
        end
        check = parent
      end
      cb(vim.fs.root(bufnr, { '.git' }) or dir)
    end,
  })
  vim.lsp.enable('powershell_es')
end
