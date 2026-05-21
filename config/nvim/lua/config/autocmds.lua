local autocmd = vim.api.nvim_create_autocmd

-- Highlight on yank
autocmd('TextYankPost', {
  callback = function() vim.highlight.on_yank({ timeout = 200 }) end,
})

-- Remove trailing whitespace on save
autocmd('BufWritePre', {
  pattern  = '*',
  command  = '%s/\\s\\+$//e',
})

-- Return to last edit position
autocmd('BufReadPost', {
  callback = function()
    local mark   = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Azure Pipelines filetype detection
autocmd({ 'BufNewFile', 'BufRead' }, {
  pattern  = { '*.azure-pipelines.yml', '*.azure-pipelines.yaml' },
  callback = function() vim.bo.filetype = 'azure-pipelines' end,
})

-- Reload buffer when file changes externally (autoread is on by default in Neovim;
-- checktime is needed to actually trigger it in terminal workflows)
autocmd({ 'FocusGained', 'BufEnter' }, {
  callback = function()
    if vim.fn.mode() ~= 'c' then vim.cmd('checktime') end
  end,
})

-- Save all modified buffers when Neovim loses focus
autocmd('FocusLost', {
  callback = function() vim.cmd('silent! wall') end,
})

-- Equalise window sizes when the terminal is resized
autocmd('VimResized', {
  callback = function() vim.cmd('wincmd =') end,
})

-- Show absolute line numbers in insert mode, relative in normal mode
autocmd('InsertEnter', {
  callback = function()
    if vim.wo.number then vim.wo.relativenumber = false end
  end,
})
autocmd('InsertLeave', {
  callback = function()
    if vim.wo.number then vim.wo.relativenumber = true end
  end,
})

-- Disable automatic comment leader continuation on Enter
autocmd('FileType', {
  pattern  = '*',
  callback = function() vim.opt_local.formatoptions:remove({ 'r', 'o', 'c' }) end,
})

-- Markdown-specific settings
autocmd('FileType', {
  pattern  = 'markdown',
  callback = function()
    vim.opt_local.wrap      = true
    vim.opt_local.spell     = true
    vim.opt_local.linebreak = true
  end,
})
