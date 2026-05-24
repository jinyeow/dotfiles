vim.g.mapleader      = ' '
vim.g.maplocalleader = '\\'

if _G.user_config.profile == 'minimal' then return end

local pack_path = vim.fn.stdpath('data') .. '/site/pack/plugins/start'

local function ensure_plugin(url, name)
  local install_path = pack_path .. '/' .. name
  if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
    print('Installing ' .. name .. '...')
    vim.fn.system({ 'git', 'clone', '--depth=1', url, install_path })
    vim.cmd('packadd ' .. name)
    return true
  end
  return false
end

local plugins = {
  { 'https://github.com/nvim-treesitter/nvim-treesitter.git',             'nvim-treesitter'             },
  { 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects.git', 'nvim-treesitter-textobjects' },
  { 'https://github.com/junegunn/fzf.git',                                'fzf'                         },
  { 'https://github.com/junegunn/fzf.vim.git',                            'fzf.vim'                     },
  { 'https://github.com/tpope/vim-fugitive.git',                          'vim-fugitive'                },
  { 'https://github.com/tpope/vim-commentary.git',                        'vim-commentary'              },
  { 'https://github.com/tpope/vim-repeat.git',                            'vim-repeat'                  },
  { 'https://github.com/catppuccin/nvim.git',                             'catppuccin'                  },
  { 'https://github.com/echasnovski/mini.nvim.git',                       'mini.nvim'                   },
  { 'https://github.com/neovim/nvim-lspconfig.git',                       'nvim-lspconfig'              },
  { 'https://github.com/b0o/schemastore.nvim.git',                        'schemastore.nvim'            },
  { 'https://github.com/lewis6991/gitsigns.nvim.git',                     'gitsigns.nvim'               },
  { 'https://github.com/MeanderingProgrammer/render-markdown.nvim.git',   'render-markdown.nvim'        },
  { 'https://github.com/swaits/zellij-nav.nvim.git',                      'zellij-nav.nvim'             },
}

local needs_ts_update = false
for _, plugin in ipairs(plugins) do
  if ensure_plugin(plugin[1], plugin[2]) then
    needs_ts_update = true
  end
end
if needs_ts_update then vim.cmd('TSUpdate') end

-- Zellij navigator: register commands (no-op when not inside Zellij)
require('zellij-nav').setup()
