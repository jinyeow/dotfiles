" ------------------"
" => BASIC SETTINGS "
" ------------------"

if has('autocmd')
  filetype plugin indent on                " load filetype-specific indent files
endif
if has('syntax') && !exists('g:syntax_on') " enable syntax processing
  syntax enable
endif

scriptencoding utf-8 " allows for arrows to display in NERDTree
set encoding=utf-8
set fileencoding=utf-8

" Search recursively into subdirectories
" set path=.,**
set path+=**

" This snippet tells Vim to look for tags files in the directory of the current
" file and in the current directory and up and up until /
set tags=./tags,tags;$HOME
if has('path_extra')
  setglobal tags-=./tags tags-=./tags; tags^=./tags;
endif

" => Spaces & Tabs
set tabstop=2     " numberof visual spaces per TAB
set softtabstop=2 " number of spaces in tab when editing
set expandtab     " tabs are spaces
set shiftwidth=2  " indenting a line with >> or << will indent or un-indent by 2
set smarttab      " indent to correct location with tab
set copyindent
set autoindent    " minimal automatic indenting for any filetype

" => matchit.vim
" enable matchit plugin which ships with vim and greatly enhances '%'
" '%' key now matches (), {}, [], def end, etc.
" Load matchit.vim, but only if the user hasn't installed a newer version.
if !exists('g:loaded_matchit') && findfile('plugin/matchit.vim', &rtp) ==# ''
  runtime! macros/matchit.vim
endif

set number         " show line numbers
set relativenumber " show relative line numbers
set ruler

set showcmd    " show command in bottom bar
set showmode

set cursorline " highlight current line

set wildmenu " visual autocomplete for command menu
set wildmode=list:full

set wildignore=*.swp,*.bak
set wildignore+=*.pyc,*.class,*.cache,*.dll,*.pdb,*.min.*
set wildignore+=*/.git/**/*,*/.hg/**/*,*/.svn/**/*
set wildignore+=tags
set wildignore+=*.tar.*
set wildignore+=*/vimundo/*

set wildignorecase

set lazyredraw
set showmatch

set laststatus=2 " 0: disable; 1: show when needed; 2: show always
set modeline     " always show file name

set textwidth=115
set backspace=indent,eol,start " makes backspace behave normally

set history=10000
set undolevels=10000 " more undos
set undofile
if !empty(glob('~/dotfiles/vimundo'))
  set undodir=~/dotfiles/vimundo/
else
  set undodir=&undodir
endif

set hidden " hides buffers; allows changing buffers without saving it first

set complete=.,b,u,w,]
set complete-=i
set completeopt=menu,menuone,preview,noinsert

set listchars=tab:▸\ ,eol:¬,trail:·,extends:❯,precedes:❮
" set nolist                " Do not show listchars
set splitbelow splitright " Open new split panes to right and bottom
set virtualedit=all
set autoread              " Set to auto read when file is changed from the outside

if !&scrolloff
  set scrolloff=3
endif
if !&sidescrolloff
  set sidescrolloff=5
endif

" set visualbell
set belloff=all

" Lower the delay of escaping out of other modes
set timeout timeoutlen=1000 ttimeoutlen=1

" when reading files try unix line endings then dos, also use unix for new buffers
set fileformats=unix,dos
set fileformat=unix " set unix line endings
set exrc
set secure

" Set clipboard to use system clipboard
if v:version < 730
  set clipboard^=unnamed,unnamedplus
else
  set clipboard^=unnamedplus,unnamed
endif

if has('unix')
  set shell=$SHELL
elseif has('win32')
  set shell=powershell.exe
  set shellcmdflag=-NoProfile\ -NoLogo\ -NonInteractive\ -Command
  set shellpipe=|
  set shellredir=>
  set shellxquote=
  " set shellquote=\"
endif

set noswapfile

set incsearch  " search as characters are entered
set hlsearch   " highlight matches
set ignorecase " ignore case when searching
set smartcase  " ...unless there's a capital letter in the query

set nojoinspaces
set diffopt=filler,vertical

set grepformat=%f:%l:%c:%m,%f:%l:%m
set nrformats=hex

set breakindent " wrapped lines are visually idented
set linebreak

" NERDTree-like netrw
let g:netrw_liststyle = 3 " tree style listing
let g:netrw_winsize   = 20 " when :Vexplore limit window size for aesthetics
let g:netrw_banner = 0
let g:netrw_browse_split = 4 " 1: new horizontal; 2: new vertical; 3: new tab; 4: previous window
augroup ProjectDrawer
  autocmd!
  autocmd VimEnter * if argc() == 0 | :Vexplore | endif
augroup END

set mouse=""

" Disable cursor-styling (I don't like the thin line cursor in insert-mode)
set guicursor=

set ttyfast

if v:version > 703 || v:version == 703 && has("patch541")
  set formatoptions+=j " Delete comment character when joining commented lines
endif

if &history < 1000
  set history=1000
endif
if &tabpagemax < 50
  set tabpagemax=50
endif

" Allow color schemes to do bright colors without forcing bold.
" NOTE: this is also in sources/colors.vim
if &t_Co == 8 && $TERM !~# '^linux\|^Eterm'
  set t_Co=16
endif

if exists('&inccommand')
  set inccommand=nosplit
endif

