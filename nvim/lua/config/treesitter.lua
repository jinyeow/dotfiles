if _G.user_config.profile == 'minimal' then
  return
end

local ok, ts = pcall(require, 'nvim-treesitter')
if not ok then
  return
end

-- On Windows the tree-sitter CLI compiles via the Rust cc crate, which defaults to cl.exe
-- (MSVC, not installed here). Point CC at a zig-cc shim (see nvim/zigcc.cmd) that rewrites
-- the forced msvc target triple to zig's bundled-mingw target - so parsers build with zig
-- alone, no LLVM/MSVC. Scoped to nvim's child processes; does not leak into the shell.
if vim.fn.has('win32') == 1 then
  vim.env.CC = vim.fs.joinpath(vim.fn.stdpath('config'), 'zigcc.cmd')
end

-- Same 16 parsers as the old ensure_installed (markdown_inline is injection-only).
-- Do NOT add 'org' - orgmode manages its own grammar (see plugins.lua).
local parsers = {
  'lua',
  'vim',
  'vimdoc',
  'python',
  'javascript',
  'typescript',
  'html',
  'css',
  'json',
  'bash',
  'markdown',
  'markdown_inline',
  'yaml',
  'powershell',
  'bicep',
  'c_sharp',
}

-- Install only what's missing (install() is async; a file opened before its parser
-- finishes compiling highlights on the next load of that buffer).
local installed = require('nvim-treesitter.config').get_installed('parsers')
local missing = vim.tbl_filter(function(lang)
  return not vim.tbl_contains(installed, lang)
end, parsers)
if #missing > 0 then
  ts.install(missing)
end

-- main no longer ships master's filetype->language table; register the non-identity
-- mappings we rely on. azure-pipelines->yaml and bicep-params->bicep are registered
-- in autocmds.lua; help->vimdoc is known to core.
vim.treesitter.language.register('powershell', 'ps1')
vim.treesitter.language.register('c_sharp', 'cs')
vim.treesitter.language.register('bash', 'sh')
vim.treesitter.language.register('javascript', 'javascriptreact')

-- Filetypes covered by the parsers above (parser name != filetype).
local filetypes = {
  'lua',
  'vim',
  'help',
  'python',
  'javascript',
  'javascriptreact',
  'typescript',
  'html',
  'css',
  'json',
  'sh',
  'bash',
  'markdown',
  'yaml',
  'azure-pipelines',
  'ps1',
  'bicep',
  'bicep-params',
  'cs',
}

local augroup = vim.api.nvim_create_augroup('config.treesitter', { clear = true })

-- Highlight + indent are per-buffer native calls on main (no highlight.enable).
-- vim.treesitter.start() also disables legacy regex syntax for the buffer, which
-- replaces the old additional_vim_regex_highlighting = false.
vim.api.nvim_create_autocmd('FileType', {
  group = augroup,
  pattern = filetypes,
  callback = function(ev)
    -- Parser may still be compiling on a fresh machine; fail quietly.
    if not pcall(vim.treesitter.start, ev.buf) then
      return
    end
    -- Experimental upstream, same status as master's indent module. Only wire it up
    -- when the parser actually ships an indents.scm (missing for c_sharp and vim as
    -- of nvim-treesitter main) - otherwise this overwrites the runtime ftplugin's
    -- working indentexpr (e.g. indent/cs.vim's GetCSIndent) with a no-op.
    local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
    if lang and vim.treesitter.query.get(lang, 'indents') then
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

-- Incremental selection was dropped from main. Neovim 0.12 ships native equivalents
-- (:h v_an - an/in/]n/[n/]N/[N + vim.treesitter.select()). Keep the old muscle memory
-- as remaps of the builtins; grc (scope-incremental) has no native equivalent and is
-- dropped.
vim.keymap.set('n', 'gnn', 'van', { remap = true, desc = 'Treesitter: select node' })
vim.keymap.set('x', 'grn', 'an', { remap = true, desc = 'Treesitter: expand to parent node' })
vim.keymap.set('x', 'grm', 'in', { remap = true, desc = 'Treesitter: shrink to child node' })

-- Textobjects: the main rewrite exposes plain Lua functions to bind yourself.
local tob_ok, textobjects = pcall(require, 'nvim-treesitter-textobjects')
if not tob_ok then
  return
end

textobjects.setup({
  select = { lookahead = true },
  move = { set_jumps = true },
})

local ts_select = require('nvim-treesitter-textobjects.select')
local function map_select(lhs, query)
  vim.keymap.set({ 'x', 'o' }, lhs, function()
    ts_select.select_textobject(query, 'textobjects')
  end, { desc = 'Treesitter select ' .. query })
end
map_select('af', '@function.outer')
map_select('if', '@function.inner')
map_select('ac', '@class.outer')
map_select('ic', '@class.inner')

local ts_move = require('nvim-treesitter-textobjects.move')
local function map_move(lhs, fn, query)
  vim.keymap.set({ 'n', 'x', 'o' }, lhs, function()
    ts_move[fn](query, 'textobjects')
  end, { desc = 'Treesitter ' .. fn:gsub('_', ' ') .. ' ' .. query })
end
map_move(']m', 'goto_next_start', '@function.outer')
map_move(']]', 'goto_next_start', '@class.outer')
map_move(']M', 'goto_next_end', '@function.outer')
map_move('][', 'goto_next_end', '@class.outer')
map_move('[m', 'goto_previous_start', '@function.outer')
map_move('[[', 'goto_previous_start', '@class.outer')
map_move('[M', 'goto_previous_end', '@function.outer')
map_move('[]', 'goto_previous_end', '@class.outer')
