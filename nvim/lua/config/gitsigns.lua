if _G.user_config.profile == 'minimal' then return end

local ok, gitsigns = pcall(require, 'gitsigns')
if not ok then return end

gitsigns.setup({
  signs = {
    add          = { text = '▎' },
    change       = { text = '▎' },
    delete       = { text = '' },
    topdelete    = { text = '' },
    changedelete = { text = '▎' },
    untracked    = { text = '▎' },
  },
  current_line_blame  = false,
  attach_to_untracked = true,
  on_attach = function(bufnr)
    local gs  = gitsigns
    local map = function(mode, keys, func, desc)
      vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = desc })
    end

    -- Hunk navigation
    map('n', ']h', function() gs.nav_hunk('next') end, 'Next hunk')
    map('n', '[h', function() gs.nav_hunk('prev') end, 'Prev hunk')

    -- Hunk actions
    map('n', '<leader>hs', gs.stage_hunk,   'Stage hunk')
    map('n', '<leader>hr', gs.reset_hunk,   'Reset hunk')
    map('v', '<leader>hs', function() gs.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') }) end, 'Stage hunk')
    map('v', '<leader>hr', function() gs.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') }) end, 'Reset hunk')
    map('n', '<leader>hS', gs.stage_buffer,     'Stage buffer')
    map('n', '<leader>hR', gs.reset_buffer,     'Reset buffer')
    map('n', '<leader>hu', gs.undo_stage_hunk,  'Undo stage hunk')
    map('n', '<leader>hp', gs.preview_hunk,     'Preview hunk')
    map('n', '<leader>hi', gs.preview_hunk_inline, 'Preview hunk inline')

    -- Blame
    map('n', '<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame line')
    map('n', '<leader>tb', gs.toggle_current_line_blame, 'Toggle line blame')

    -- Diff
    map('n', '<leader>hd', gs.diffthis,                      'Diff this')
    map('n', '<leader>hD', function() gs.diffthis('~') end,  'Diff against last commit')

    -- Text object
    map({ 'o', 'x' }, 'ih', '<cmd>Gitsigns select_hunk<CR>', 'Select hunk')
  end,
})
