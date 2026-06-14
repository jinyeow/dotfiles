if _G.user_config.profile == 'minimal' then return end

local ok, configs = pcall(require, 'nvim-treesitter.configs')
if not ok then return end

configs.setup({
  ensure_installed = {
    'lua', 'vim', 'vimdoc',
    'python', 'javascript', 'typescript',
    'html', 'css', 'json', 'bash',
    'markdown', 'markdown_inline',
    'yaml', 'powershell', 'bicep',
    'c_sharp',
  },
  auto_install = false,
  highlight = {
    enable                            = true,
    additional_vim_regex_highlighting = false,
  },
  indent = { enable = true },
  incremental_selection = {
    enable  = true,
    keymaps = {
      init_selection    = 'gnn',
      node_incremental  = 'grn',
      scope_incremental = 'grc',
      node_decremental  = 'grm',
    },
  },
  textobjects = {
    select = {
      enable    = true,
      lookahead = true,
      keymaps   = {
        ['af'] = '@function.outer',
        ['if'] = '@function.inner',
        ['ac'] = '@class.outer',
        ['ic'] = '@class.inner',
      },
    },
    move = {
      enable    = true,
      set_jumps = true,
      goto_next_start     = { [']m'] = '@function.outer', [']]'] = '@class.outer' },
      goto_next_end       = { [']M'] = '@function.outer', [']['] = '@class.outer' },
      goto_previous_start = { ['[m'] = '@function.outer', ['[['] = '@class.outer' },
      goto_previous_end   = { ['[M'] = '@function.outer', ['[]'] = '@class.outer' },
    },
  },
})
