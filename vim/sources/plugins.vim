" vim:foldmethod=marker:foldlevel=0
" ------------------"
" => PLUGINS        "
" ------------------"

let plug_path = vim_dotdir . '/common'

" Load Plugins
call plug#begin(plug_path . '/plugged')

" => AutoCompletes {{{
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'SirVer/ultisnips'
Plug 'jiangmiao/auto-pairs'

" Plug 'Raimondi/delimitMate'
"Plug 'mattn/emmet-vim', { 'for': ['html', 'xml', 'xhtml', 'eelixir', 'eruby', 'jsx'] }
"Plug 'racer-rust/vim-racer', { 'for': 'rust' }
" }}}
" => Browsing/Side-Bars {{{
Plug 'mbbill/undotree', { 'on': 'UndotreeToggle' }
if v:version >= 703 | Plug 'majutsushi/tagbar' | endif
" }}}
" => Colorscheme(s) {{{
Plug 'iCyMind/NeoSolarized'
Plug 'drewtempelmeyer/palenight.vim'
Plug 'morhetz/gruvbox'
Plug 'rakr/vim-one'
Plug 'sonph/onehalf'
Plug 'mhinz/vim-janah'
Plug 'joshdick/onedark.vim'
Plug 'danilo-augusto/vim-afterglow'
Plug 'chriskempson/base16-vim'
Plug 'mhartington/oceanic-next'
Plug 'kristijanhusak/vim-hybrid-material'
Plug 'NLKNguyen/papercolor-theme'
Plug 'noahfrederick/vim-noctu'
Plug 'flaflasun/vim-nightowl'
Plug 'arcticicestudio/nord-vim'
Plug 'cocopon/iceberg.vim'
Plug 'skbolton/embark'
" }}}
" => Git {{{
Plug 'tpope/vim-fugitive'
"Plug 'airblade/vim-gitgutter'
" }}}
" => Grepping {{{
Plug 'mhinz/vim-grepper'
" Plug 'tracyone/fzf-funky' " Can use :FzfBTags instead
" }}}
" => Language-Related/Syntax {{{
" Uncomment the languages you need
if has('win32')
  Plug 'PProvost/vim-ps1'
elseif has('unix')
  Plug 'vim-scripts/c.vim',       { 'for': ['c', 'h', 'cpp', 'hpp'] }
  Plug 'tpope/vim-rails',         { 'for': ['ruby', 'eruby'] }
  " Plug 'lervag/vimtex',   { 'for': ['tex', 'bib', 'plaintex'] }
  " NOTE: for these avr syntax files to work use ':set syntax=[avr-syntax-file.vim]'
  " Plug 'jinyeow/avr.vim', { 'for': 'asm' }
endif

" NOTE: js/ts support
Plug 'pangloss/vim-javascript'    " JavaScript support
Plug 'leafgarland/typescript-vim' " TypeScript syntax
Plug 'maxmellon/vim-jsx-pretty'   " JS and JSX syntax
Plug 'jparise/vim-graphql'        " GraphQL syntax
" }}}
" => Misc {{{
Plug 'duggiefresh/vim-easydir'
Plug 'henrik/vim-indexed-search'
Plug 'airblade/vim-rooter'
Plug 'AndrewRadev/splitjoin.vim'
Plug 'romainl/vim-qf'
Plug 'romainl/vim-qlist'
Plug 'kshenoy/vim-signature' " displays marks
Plug 'chrisbra/vim-diff-enhanced'
Plug 'haya14busa/vim-asterisk'
Plug 'farmergreg/vim-lastplace'

" NOTE: install for CSS/HTML only.
" Plug 'lilydjwg/colorizer'

if has('unix')
  Plug 'powerman/vim-plugin-AnsiEsc'
  Plug 'francoiscabrol/ranger.vim'
endif

" Plug 'skywind3000/asyncrun.vim'
" }}}
" => Textobj {{{
Plug 'wellle/targets.vim'
" Plug 'kana/vim-textobj-user'
" Plug 'tek/vim-textobj-ruby',     { 'for': ['ruby', 'eruby'] }
" Plug 'andyl/vim-textobj-elixir', { 'for': ['elixir', 'escript'] }
" Plug 'bps/vim-textobj-python', { 'for': 'python' }
" Plug 'kana/vim-textobj-function'
" Plug 'whatyouhide/vim-textobj-xmlattr'
" }}}
" => Tmux {{{
if has('unix')
  Plug 'christoomey/vim-tmux-navigator'
  Plug 'tmux-plugins/vim-tmux'
endif
" }}}
" => UI {{{
if has('unix') | Plug 'terryma/vim-smooth-scroll' | endif
Plug 'Yggdroot/indentLine'
" Plug 'zhamlin/tiler.vim'
" }}}

" => junegunn Plugins {{{
Plug 'junegunn/vim-peekaboo'
Plug 'junegunn/vim-easy-align', { 'on': ['<Plug>(EasyAlign)', 'EasyAlign'] }
Plug 'junegunn/fzf',            { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-slash'
" }}}
" => tpope Plugins {{{
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-ragtag'
" Plug 'tpope/vim-sleuth' " heuristically set 'shiftwidth' and 'expandtab'. fully automatic indent settings.
" Plug 'tpope/vim-projectionist'
" Plug 'tpope/vim-markdown', { 'for': ['markdown', 'md'] }
" Plug 'tpope/vim-dispatch'

if has('unix')
  Plug 'tpop/vim-vinegar' " NOTE: some errors with installing on Windows
endif
" }}}

call plug#end()

let g:plug_threads = 80

