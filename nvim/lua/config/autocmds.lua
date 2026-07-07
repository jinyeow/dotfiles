local autocmd = vim.api.nvim_create_autocmd

-- Highlight on yank
autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

-- Remove trailing whitespace on save
autocmd('BufWritePre', {
  pattern = '*',
  command = '%s/\\s\\+$//e',
})

-- Return to last edit position
autocmd('BufReadPost', {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Azure Pipelines filetype detection. Covers both the `*.azure-pipelines.yml`
-- convention and the Azure DevOps default filename `azure-pipelines.yml` at repo
-- root, so azure_pipelines_ls (not yamlls) attaches to both. See lsp.lua.
autocmd({ 'BufNewFile', 'BufRead' }, {
  pattern = { '*.azure-pipelines.yml', '*.azure-pipelines.yaml', 'azure-pipelines.yml', 'azure-pipelines.yaml' },
  callback = function()
    vim.bo.filetype = 'azure-pipelines'
  end,
})

-- The azure-pipelines filetype has no Treesitter grammar of its own; map it to
-- the yaml parser so highlighting/indent work (azure_pipelines_ls still attaches
-- exclusively via the dedicated filetype). See lsp.lua.
vim.treesitter.language.register('yaml', 'azure-pipelines')

-- Reload buffer when file changes externally (autoread is on by default in Neovim;
-- checktime is needed to actually trigger it in terminal workflows)
autocmd({ 'FocusGained', 'BufEnter' }, {
  callback = function()
    if vim.fn.mode() ~= 'c' then
      vim.cmd('checktime')
    end
  end,
})

-- Save all modified buffers when Neovim loses focus
autocmd('FocusLost', {
  callback = function()
    vim.cmd('silent! wall')
  end,
})

-- Equalise window sizes when the terminal is resized
autocmd('VimResized', {
  callback = function()
    vim.cmd('wincmd =')
  end,
})

-- Show absolute line numbers in insert mode, relative in normal mode
autocmd('InsertEnter', {
  callback = function()
    if vim.wo.number then
      vim.wo.relativenumber = false
    end
  end,
})
autocmd('InsertLeave', {
  callback = function()
    if vim.wo.number then
      vim.wo.relativenumber = true
    end
  end,
})

-- Disable automatic comment leader continuation on Enter
autocmd('FileType', {
  pattern = '*',
  callback = function()
    vim.opt_local.formatoptions:remove({ 'r', 'o', 'c' })
  end,
})

-- Markdown-specific settings
autocmd('FileType', {
  pattern = 'markdown',
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
    vim.opt_local.linebreak = true
  end,
})

-- Alternate between a source file and its mirrored test file (C# / PowerShell).
--   C#:  src/<Proj>/<rest>/Foo.cs   <->  tests/<Proj>.Tests/<rest>/FooTests.cs
--   PS:  src/<rest>/Foo.ps1         <->  tests/<rest>/Foo.Tests.ps1
-- Opens the counterpart if it exists, otherwise an unsaved buffer at the target
-- path (parent dirs are created on first write, not on navigation).
local function alternate_test_file()
  local abs = vim.api.nvim_buf_get_name(0):gsub('\\', '/')
  if abs == '' then
    return vim.notify('Alternate: no file in buffer', vim.log.levels.WARN)
  end
  local root = vim.fs.root(abs, { '.git', '.jj' })
  if not root then
    return vim.notify('Alternate: not inside a project (no .git/.jj root)', vim.log.levels.WARN)
  end
  root = root:gsub('\\', '/')

  -- Segments relative to the project root, so only the project's own top-level
  -- src/ or tests/ anchors the toggle (not an ancestor or a nested one).
  local segs = vim.split(abs:sub(#root + 2), '/', { plain = true })
  if segs[1] ~= 'src' and segs[1] ~= 'tests' then
    return vim.notify('Alternate: not under the project src/ or tests/ tree', vim.log.levels.WARN)
  end

  local to_test = segs[1] == 'src'
  local is_cs = vim.bo.filetype == 'cs'
  segs[1] = to_test and 'tests' or 'src'

  -- C# only: the project folder (segment after src/tests) gains/loses the .Tests
  -- suffix; #segs > 2 means such a folder exists (segs[2] is not the file itself).
  if is_cs and #segs > 2 then
    segs[2] = to_test and (segs[2] .. '.Tests') or segs[2]:gsub('%.Tests$', '')
  end

  -- filename suffix
  local name = segs[#segs]
  if is_cs then
    name = to_test and name:gsub('%.cs$', 'Tests.cs') or name:gsub('Tests%.cs$', '.cs')
  else -- ps1
    name = to_test and name:gsub('%.ps1$', '.Tests.ps1') or name:gsub('%.Tests%.ps1$', '.ps1')
  end
  segs[#segs] = name

  local target = root .. '/' .. table.concat(segs, '/')
  vim.cmd.edit(vim.fn.fnameescape(target))
  if vim.fn.filereadable(target) == 0 then
    vim.api.nvim_create_autocmd('BufWritePre', {
      buffer = 0,
      once = true,
      callback = function(ev)
        vim.fn.mkdir(vim.fn.fnamemodify(ev.match, ':h'), 'p')
      end,
    })
  end
end

-- Lazy-bind the alternate-file keymap only in C#/PowerShell buffers
autocmd('FileType', {
  pattern = { 'cs', 'ps1' },
  callback = function(ev)
    vim.keymap.set('n', '<leader>A', alternate_test_file, { buffer = ev.buf, desc = 'Alternate source/test file' })
  end,
})
