" Note: Skip initialization for vim-tiny or vim-small
if !1 | finish | endif

if has('vim_starting')
    set nocompatible " Be iMproved

    " Required:
    set runtimepath+=~/.vim/bundle/neobundle.vim
endif

" Required:
call neobundle#begin(expand('~/.vim/bundle/'))

" Let NeoBundle mangage NeoBundle
" Required:
NeoBundleFetch 'Shougo/neobundle.vim'

" ========================================================================
" => BUNDLES [refer to |:NeoBundle-examples.|]
" ========================================================================
" Vimproc
NeoBundle 'Shougo/vimproc.vim', {
\ 'build' : {
\     'windows' : 'tools\\update-dll-mingw',
\     'cygwin' : 'make -f make_cygwin.mak',
\     'mac' : 'make -f make_mac.mak',
\     'linux' : 'make',
\     'unix' : 'gmake',
\    },
\ }

" Vimshell
NeoBundle 'Shougo/vimshell.vim'

" => Neocomplete/Neocomplcache
if !(has('lua') && (v:version > 703 || v:version == 703 && has('patch885')))
  NeoBundle 'Shougo/neocomplcache.vim'
elseif (has('nvim'))
  NeoBundle 'Shougo/neocomplcache.vim'
else
  NeoBundle 'Shougo/neocomplete.vim'
endif

" => AutoCompletes
NeoBundle 'ervandew/supertab'
NeoBundle 'Raimondi/delimitMate'
NeoBundle 'amirh/HTML-AutoCloseTag'
" NeoBundle 'artur-shaik/vim-javacomplete2'

" => Colorschemes
" NeoBundle 'flazz/vim-colorschemes'
NeoBundle 'chriskempson/base16-vim'

" => Git
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'airblade/vim-gitgutter'

" => Filetypes Syntax
" NeoBundle 'tpope/vim-haml'
NeoBundle 'mattn/emmet-vim'
" NeoBundleLazy 'slim-template/vim-slim',    {'autoload':{'filetypes':['slim']}}
" NeoBundleLazy 'cakebaker/scss-syntax.vim', {'autoload':{'filetypes':['scss']}}
NeoBundleLazy 'tpope/vim-markdown',        {'autoload':{'filetypes':['md']}}

" => Fuzzy search:CtrlP
NeoBundle 'mileszs/ack.vim'
NeoBundle 'rking/ag.vim'
NeoBundle 'kien/ctrlp.vim'
NeoBundle 'sgur/ctrlp-extensions.vim'
NeoBundle 'fisadev/vim-ctrlp-cmdpalette'
NeoBundle 'Felikz/ctrlp-py-matcher'
" NeoBundle 'tacahiroy/ctrlp-funky'
" NeoBundle 'DavidEGx/ctrlp-smarttabs'

" => Motion
NeoBundle 'Lokaltog/vim-easymotion'
NeoBundle 'terryma/vim-multiple-cursors'

" => Ruby
NeoBundleLazy 'skalnik/vim-vroom',       {'autoload':{'filetypes':['ruby', 'rb', 'erb', 'slim']}}
NeoBundleLazy 'vim-ruby/vim-ruby',       {'autoload':{'filetypes':['ruby', 'rb', 'erb', 'slim']}}
NeoBundleLazy 'tpope/vim-endwise',       {'autoload':{'filetypes':['ruby', 'rb']}}
NeoBundleLazy 'tpope/vim-rails',         {'autoload':{'filetypes':['ruby', 'rb', 'erb', 'slim']}}
NeoBundleLazy 't9md/vim-ruby-xmpfilter', {'autoload':{'filetypes':['ruby', 'rb']}}
NeoBundleLazy 'osyo-manga/vim-monster',  {'autoload':{'filetypes':['ruby', 'rb']}}
" NeoBundleLazy 'tpope/vim-bundler', {'autoload':{'filetypes':['ruby', 'rb', 'erb']}}
" NeoBundleLazy 'tpope/vim-rake', {'autoload':{'filetypes':['ruby', 'rb', 'erb']}}
" NeoBundleLazy 'thoughtbot/vim-rspec', {'autoload':{'filetypes':['ruby', 'rb', 'erb']}}

" => Syntax
NeoBundle 'sheerun/vim-polyglot'
NeoBundle 'scrooloose/syntastic'

" => Unite.vim
" NeoBundle 'Shougo/unite.vim'
" NeoBundle 'Shougo/unite-outline'
" NeoBundle 'Shougo/unite-help'
" NeoBundle 'Shougo/unite-session'
" NeoBundle 'Shougo/neomru.vim'
" NeoBundle 'thinca/vim-unite-history'

" => Misc
NeoBundle 'scrooloose/nerdtree'
NeoBundle 'godlygeek/tabular'
NeoBundle 'mbbill/undotree'
NeoBundle 'pbrisbin/vim-mkdir'
NeoBundle 'terryma/vim-smooth-scroll'
NeoBundle 'zhaocai/GoldenView.Vim'
NeoBundle 'lilydjwg/colorizer'
" NeoBundle 'wellle/targets.vim'
" NeoBundle 'xolox/vim-notes'
" NeoBundle 'jceb/vim-orgmode'
" NeoBundle 'vimwiki/vimwiki'

" => Tpope Plugins:
NeoBundle 'tpope/vim-eunuch'
NeoBundle 'tpope/vim-surround'
NeoBundle 'tpope/vim-unimpaired'
NeoBundle 'tpope/vim-commentary'
" NeoBundle 'tpope/vim-repeat'
" NeoBundle 'tpope/vim-heroku'
" NeoBundle 'tpope/vim-dispatch'

" => junegunn Plugins:
" NeoBundle 'junegunn/vim-plug'

if has('unix')
  NeoBundle 'majutsushi/tagbar'
  NeoBundle 'edkolev/tmuxline.vim'
  NeoBundle 'tpope/vim-tbone'
  NeoBundle 'christoomey/vim-tmux-navigator'
  NeoBundle 'keith/tmux.vim' " Add syntax highlighting for *tmux.conf files
endif

call neobundle#end()
NeoBundleCheck

" ========================================================================
" => AUTOGROUPS
" ========================================================================
augroup MyAutoCmd
    autocmd!
    " Reload vimrc when edited
    autocmd MyAutoCmd BufWritePost .vimrc,_vimrc,vimrc,.gvimrc,_gvimrc,gvimrc
          \ so % | if has('gui_running') | so % | endif
    " Change working directory to current file's directory
    autocmd BufEnter * lcd %:p:h
    autocmd BufWrite * :call DeleteTrailingWS()
augroup END

augroup ctype
    autocmd!
    autocmd BufRead,BufNewFile *.h,*.c set filetype=c
augroup END

" Enable slim syntax highlighting
autocmd FileType slim setlocal foldmethod=indent
autocmd BufNewFile,BufRead *.slim set filetype=slim

" Save on losing focus i.e. tabbing away from vim
au FocusLost * :wa

" ========================================================================
" => Spaces & Tabs
" ========================================================================
set tabstop=2 " numberof visual spaces per TAB
set softtabstop=2 " number of spaces in tab when editing
set expandtab " tabs are spaces
set shiftwidth=2 " indenting a line with >> or << will indent or un-indent by 4
set smarttab " indent to correct location with tab
set autoindent
set copyindent

" if filetype is ruby, javascript, html set tab to 2 spaces instead of 4
if has("autocmd")
  autocmd FileType python,c,h setlocal tabstop=4
  autocmd FileType python,c,h setlocal shiftwidth=4
  autocmd FileType python,c,h setlocal softtabstop=4
  autocmd FileType python,c,h setlocal nowrap
endif

" ========================================================================
" => UI Config
" ========================================================================
filetype plugin indent on " load filetype-specific indent files
syntax enable " enable syntax processing
scriptencoding utf-8 " allows for arrows to display in NERDTree
set encoding=utf-8
set fileencoding=utf-8
set number " show line numbers
set numberwidth=3
set relativenumber " show relative line numbers
set ruler
set showcmd " show command in bottom bar
set showmode
set cursorline " highlight current line
set wildmenu " visual autocomplete for command menu
" set wildmode=list:longest " suggestions for normal mode commands
set lazyredraw " redraw only when we need to
set showmatch " highlight mathching [{()}]
set textwidth=80 " any line will only be maximum 80 characters long
set colorcolumn=80 " column 80 is a different color
set backspace=indent,eol,start " makes backspace behave normally
set history=10000
set undolevels=10000 " more undos
set undofile
set undodir=~/dotfiles/.vimundo/
set hidden " hides buffers; allows changing buffers without saving it first
set modeline " always show file name
set completeopt-=preview
set ls=2 " Always show statusline
set list listchars=tab:▸\ ,eol:¬,trail:·
set splitright splitbelow " Open new split panes to right and bottom
set virtualedit=onemore " allow for cursor beyond last character
set autoread " Set to auto read when file is changed from the outside
set scrolloff=10
set vb " Turn off (sound) visual bell
set t_vb=

" Maximizes gVim window
if has('win32')
  au GUIEnter * simalt ~x
endif

" Don't show menu/toolbar/scrollbar
if has('gui_running')
  set go-=m " remove menu bar
  set go-=T " remove toolbar
  set go-=r " remove right-hand scroll bar
  set go-=L " remove left-hand scroll bar
endif

" Lower the delay of escaping out of other modes
set timeout timeoutlen=1000 ttimeoutlen=1

" enable matchit plugin which ships with vim and greatly enhances '%'
runtime macros/matchit.vim

" when reading files try unix line endings then dos, also use unix for new buffers
set fileformats=unix,dos
set fileformat=unix " set unix line endings
set exrc
set secure
set clipboard^=unnamed " Set clipboard to use system clipboard

" ========================================================================
" => Turn off Swap Files
" ========================================================================
set noswapfile
set nobackup
set nowb

" ========================================================================
" => Searching
" ========================================================================
set incsearch " search as characters are entered
set hlsearch " highlight matches
set ignorecase " ignore case when searching
set smartcase " ...unless there's a capital letter in the query

" turn off search highlight
nnoremap <silent>  <space> :nohlsearch<CR>

" Highlight Search terminal (cterm) color change
hi Search cterm=NONE ctermfg=0 ctermbg=222 guifg=000000 guibg=ffe792

" changes the default Vim regexes to sane/regular regex. or something.
nnoremap / /\v
vnoremap / /\v
nnoremap ? ?\v
vnoremap ? ?\v
nnoremap :s/ :s/\v

set gdefault " defaults substitutions globally on lines

" center screen when scrolling search results
nnoremap n nzz
nnoremap N Nzz

" ========================================================================
" => Folding
" ========================================================================
set foldenable " enable folding
set foldlevelstart=10 " open most folds by default
set foldnestmax=10 " 10 nested fold max
" space toggles folds
nnoremap <leader><space> za
set foldmethod=indent " fold based on indent level
set modelines=1

" ========================================================================
" => Movement
" ========================================================================
" move vertically by visual line
nnoremap j gj
nnoremap k gk

" move to begging/end of line
nnoremap B ^
nnoremap E $
map 0 ^

" unmap arrow keys
nnoremap <up> <nop>
nnoremap <down> <nop>
nnoremap <left> <nop>
nnoremap <right> <nop>
map <right> <ESC>:bn<RETURN>
map <left> <ESC>:bp<RETURN>

" Retain visual selection after indenting
vnoremap < <gv
vnoremap > >gv
vnoremap <S-Tab> <gv
vnoremap <Tab> >gv

" ========================================================================
" => Leader Shortcuts
" ========================================================================
let mapleader=","
let g:mapleader=","

" jk/jj/ is escape
inoremap jk <esc>
inoremap jj <esc>

" ========================================================================
" => Other Shortcuts
" ========================================================================
inoremap <Leader><Tab> <C-X><C-O>

" ========================================================================
" => SUPERTAB
" ========================================================================
let g:SuperTabDefaultCompletionType = "<C-n>"

" ========================================================================
" => SYNTASTIC
" ========================================================================
" mark syntax errors with :signs
let g:syntastic_enable_signs  = 1
" automatically jump to the error when saving the file
let g:syntastic_auto_jump     = 0
" show the error list automatically
let g:syntastic_auto_loc_list = 1
" configure syntastic syntax checking to check on open as well as save
let g:syntastic_check_on_open = 1
let g:syntastic_ruby_checkers = ['mri']
let g:syntastic_mode_map      = { "mode": "active", "passive_filetypes": ["java"] }

" ========================================================================
" => TAGBAR
" ========================================================================
nmap <S-t> :TagbarToggle<CR>

" ========================================================================
" => GITGUTTER
" ========================================================================
let g:gitgutter_map_keys = 0

" ========================================================================
" => NERDTREE
" ========================================================================
let NERDTreeDirArrows  = 1
let g:NERDTreeWinSize  = 30
let NERDTreeQuitOnOpen = 1
nnoremap <silent> <S-Tab> :NERDTreeToggle<CR>

" Reveal current file in NERDTree with Shift + c
map <silent> <S-c> :NERDTreeFind<CR>

" Show NERDTree on startup if no file specified
function! StartUp()
    if 0 == argc()
        NERDTree
    endif
endfunction
autocmd VimEnter * call StartUp()

let NERDTreeIgnore = ['\~$', '\.swp$', '\.git', '\.hg', '\.svn', '\.bzr']

" ========================================================================
" => EASYMOTION
" ========================================================================
let g:EasyMotion_do_mapping = 0 " Disable default mappings

" Bi-directional find motion
" Jump to anywhere you want with minimal keystrokes, with just one key
" binding.
" `s{char}{label}`
nmap s <Plug>(easymotion-s)
" or
" `s{char}{char}{label}`
" Need one more keystroke, but on average, it may be more comfortable.
nmap S <Plug>(easymotion-s2)

" Turn on case sensitive feature
let g:EasyMotion_smartcase = 1

" JK motions: Line motions
map <Leader>j <Plug>(easymotion-j)
map <Leader>k <Plug>(easymotion-k)
map <Leader>l <Plug>(easymotion-lineforward)
map <Leader>h <Plug>(easymotion-linebackward)

let g:EasyMotion_startofline = 0 " keep cursor column when JK motion

" Search with Easymotion
map / <Plug>(easymotion-sn)
omap / <Plug>(easymotion-tn)
map n <Plug>(easymotion-next)
map N <Plug>(easymotion-prev)

" ========================================================================
" => NEOCOMPLETE -> review settings for unknowns!
" ========================================================================
" if version is < 7.3 or not lua compatible use Neocomplcache
" else use Neocomplete
if !(has('lua') && (v:version > 703 || v:version == 703 && has('patch885')))
  " Disable AutoComplPop.
  let g:acp_enableAtStartup = 0
  " Use neocomplcache.
  let g:neocomplcache_enable_at_startup = 1
  " Use smartcase.
  let g:neocomplcache_enable_smart_case = 1
  " Set minimum syntax keyword length.
  let g:neocomplcache_min_syntax_length = 3
  let g:neocomplcache_lock_buffer_name_pattern = '\*ku\*'

  " Enable heavy features.
  " Use camel case completion.
  "let g:neocomplcache_enable_camel_case_completion = 1
  " Use underbar completion.
  "let g:neocomplcache_enable_underbar_completion = 1

  " Define dictionary.
  let g:neocomplcache_dictionary_filetype_lists = {
      \ 'default' : '',
      \ 'vimshell' : $HOME.'/.vimshell_hist',
      \ 'scheme' : $HOME.'/.gosh_completions'
          \ }

  " Define keyword.
  if !exists('g:neocomplcache_keyword_patterns')
      let g:neocomplcache_keyword_patterns = {}
  endif
  let g:neocomplcache_keyword_patterns['default'] = '\h\w*'

  " Plugin key-mappings.
  inoremap <expr><C-g>     neocomplcache#undo_completion()
  inoremap <expr><C-l>     neocomplcache#complete_common_string()

  " Recommended key-mappings.
  " <CR>: close popup and save indent.
  inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
  function! s:my_cr_function()
    return neocomplcache#smart_close_popup() . "\<CR>"
    " For no inserting <CR> key.
    "return pumvisible() ? neocomplcache#close_popup() : "\<CR>"
  endfunction
  " <TAB>: completion.
  inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
  " <C-h>, <BS>: close popup and delete backword char.
  inoremap <expr><C-h> neocomplcache#smart_close_popup()."\<C-h>"
  inoremap <expr><BS> neocomplcache#smart_close_popup()."\<C-h>"
  inoremap <expr><C-y>  neocomplcache#close_popup()
  inoremap <expr><C-e>  neocomplcache#cancel_popup()
  " Close popup by <Space>.
  "inoremap <expr><Space> pumvisible() ? neocomplcache#close_popup() : "\<Space>"

  " For cursor moving in insert mode(Not recommended)
  "inoremap <expr><Left>  neocomplcache#close_popup() . "\<Left>"
  "inoremap <expr><Right> neocomplcache#close_popup() . "\<Right>"
  "inoremap <expr><Up>    neocomplcache#close_popup() . "\<Up>"
  "inoremap <expr><Down>  neocomplcache#close_popup() . "\<Down>"
  " Or set this.
  "let g:neocomplcache_enable_cursor_hold_i = 1
  " Or set this.
  "let g:neocomplcache_enable_insert_char_pre = 1

  " AutoComplPop like behavior.
  "let g:neocomplcache_enable_auto_select = 1

  " Shell like behavior(not recommended).
  "set completeopt+=longest
  "let g:neocomplcache_enable_auto_select = 1
  "let g:neocomplcache_disable_auto_complete = 1
  "inoremap <expr><TAB>  pumvisible() ? "\<Down>" : "\<C-x>\<C-u>"

  " Enable omni completion.
  autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
  autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
  autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
  autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
  autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags

  " Enable heavy omni completion.
  if !exists('g:neocomplcache_force_omni_patterns')
    let g:neocomplcache_force_omni_patterns = {}
  endif
  let g:neocomplcache_force_omni_patterns.php = '[^. \t]->\h\w*\|\h\w*::'
  let g:neocomplcache_force_omni_patterns.c = '[^.[:digit:] *\t]\%(\.\|->\)'
  let g:neocomplcache_force_omni_patterns.cpp = '[^.[:digit:] *\t]\%(\.\|->\)\|\h\w*::'

  " For perlomni.vim setting.
  " https://github.com/c9s/perlomni.vim
  let g:neocomplcache_force_omni_patterns.perl = '\h\w*->\h\w*\|\h\w*::'
else
  " Disable AutoComplPop
  let g:acp_enableAtStartup = 0
  " Use neocomplete.
  let g:neocomplete#enable_at_startup = 1
  " Use smartcase.
  let g:neocomplete#enable_smart_case = 1
  " Set minimum syntax keyword length.
  let g:neocomplete#sources#syntax#min_keyword_length = 3
  let g:neocomplete#lock_buffer_name_pattern = '\*ku\*'

  " Define dictionary.
  let g:neocomplete#sources#dictionary#dictionaries = {
      \ 'default' : '',
      \ 'vimshell' : $HOME.'/.vimshell_hist',
      \ 'scheme' : $HOME.'/.gosh_completions'
          \ }

  " Define keyword.
  if !exists('g:neocomplete#keyword_patterns')
      let g:neocomplete#keyword_patterns = {}
  endif
  let g:neocomplete#keyword_patterns['default'] = '\h\w*'

  " Plugin key-mappings.
  inoremap <expr><C-g>     neocomplete#undo_completion()
  inoremap <expr><C-l>     neocomplete#complete_common_string()

  " Recommended key-mappings.
  " <CR>: close popup and save indent.
  inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
  function! s:my_cr_function()
    return neocomplete#close_popup() . "\<CR>"
    " For no inserting <CR> key.
    "return pumvisible() ? neocomplete#close_popup() : "\<CR>"
  endfunction
  " <TAB>: completion.
  inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
  " <C-h>, <BS>: close popup and delete backword char.
  inoremap <expr><C-h> neocomplete#smart_close_popup()."\<C-h>"
  inoremap <expr><BS> neocomplete#smart_close_popup()."\<C-h>"
  inoremap <expr><C-y>  neocomplete#close_popup()
  inoremap <expr><C-e>  neocomplete#cancel_popup()
  " Close popup by <Space>.
  "inoremap <expr><Space> pumvisible() ? neocomplete#close_popup() : "\<Space>"

  " For cursor moving in insert mode(Not recommended)
  "inoremap <expr><Left>  neocomplete#close_popup() . "\<Left>"
  "inoremap <expr><Right> neocomplete#close_popup() . "\<Right>"
  "inoremap <expr><Up>    neocomplete#close_popup() . "\<Up>"
  "inoremap <expr><Down>  neocomplete#close_popup() . "\<Down>"
  " Or set this.
  "let g:neocomplete#enable_cursor_hold_i = 1
  " Or set this.
  "let g:neocomplete#enable_insert_char_pre = 1

  " AutoComplPop like behavior.
  "let g:neocomplete#enable_auto_select = 1

  " Shell like behavior(not recommended).
  "set completeopt+=longest
  "let g:neocomplete#enable_auto_select = 1
  "let g:neocomplete#disable_auto_complete = 1
  "inoremap <expr><TAB>  pumvisible() ? "\<Down>" : "\<C-x>\<C-u>"

  " Enable omni completion.
  autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
  autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
  autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
  autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
  autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
  autocmd FileType ruby setlocal omnifunc=rubycomplete#Complete

  let g:rubycomplete_buffer_loading = 1
  let g:rubycomplete_classes_in_global = 1

  " Enable heavy omni completion.
  if !exists('g:neocomplete#sources#omni#input_patterns')
    let g:neocomplete#sources#omni#input_patterns = {}
  endif
  "let g:neocomplete#sources#omni#input_patterns.php = '[^. \t]->\h\w*\|\h\w*::'
  "let g:neocomplete#sources#omni#input_patterns.c = '[^.[:digit:] *\t]\%(\.\|->\)'
  "let g:neocomplete#sources#omni#input_patterns.cpp = '[^.[:digit:] *\t]\%(\.\|->\)\|\h\w*::'

  " For perlomni.vim setting.
  " https://github.com/c9s/perlomni.vim
  let g:neocomplete#sources#omni#input_patterns.perl = '\h\w*->\h\w*\|\h\w*::'

  " Added 26/04/2015 11:39 to help with Ruby autocomplete
  let g:neocomplete#enable_at_startup = 1
  let g:neocomplete#enable_fuzzy_completion = 1
  let g:neocomplete_enable_fuzzy_completion_start_length = 2
  let g:neocomplete_enable_camel_case_completion = 0
  let g:neocomplete#enable_smart_case = 1
  let g:neocomplete#enable_auto_delimiter = 1
  let g:neocomplete#max_list = 10
  let g:neocomplete#force_overwrite_completefunc = 1
  let g:neocomplete#enable_auto_select = 0
endif

" ========================================================================
" => VROOM --run ruby test specs from vim
" ========================================================================
let g:vroom_clear_screen = 0

" ========================================================================
" => VIM-RUBY-XMPFILTER
" ========================================================================
let g:xmpfilter_cmd = "seeing_is_believing"

autocmd FileType ruby nmap <buffer> <C-m> <Plug>(seeing_is_believing-mark)
autocmd FileType ruby xmap <buffer> <C-m> <Plug>(seeing_is_believing-mark)
autocmd FileType ruby nmap <buffer> <C-c> <Plug>(seeing_is_believing-clean)
autocmd FileType ruby xmap <buffer> <C-c> <Plug>(seeing_is_believing-clean)

" xmpfilter compatible
autocmd FileType ruby nmap <buffer> <C-x> <Plug>(seeing_is_believing-run_-x)
autocmd FileType ruby xmap <buffer> <C-x> <Plug>(seeing_is_believing-run_-x)

" auto insert mark at appropriate spot.
autocmd FileType ruby nmap <buffer> <C-b> <Plug>(seeing_is_believing-run)
autocmd FileType ruby xmap <buffer> <C-b> <Plug>(seeing_is_believing-run)
autocmd FileType ruby imap <buffer> <C-b> <Plug>(seeing_is_believing-run)
autocmd FileType ruby nmap <buffer> <Leader>b <Plug>(seeing_is_believing-mark)<Plug>(seeing_is_believing-run_-x)

" ========================================================================
" => CTRLP
" ========================================================================
" let g:ctrlp_map = '<C-p>'
" let g:ctrlp_cmd = 'CtrlP'

let g:ctrlp_extensions = ['buffertag', 'dir', 'undo', 'line', 'changes', 'mixed']

" The Silver Searcher
if executable('ag')
  " Use ag over grep
  set grepprg=ag\ --nogroup\ --nocolor

  " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
  let g:ctrlp_user_command = 'ag %s -l --nocolor --nogroup --hidden
      \ --ignore .git
      \ --ignore .svn
      \ --ignore .hg
      \ --ignore .DS_Store
      \ --ignore "**/*.pyc"
      \ -g ""'

  " Ag is fast enough that ctrlp does not need to cache
  " let g:ctrlp_use_caching = 0
endif

" Shift+h to use Yankring to get history of paste buffers (?)
map <S-h> :CtrlPYankring<CR>

" Ctrl+Shift+p to use CtrlPCmdPalette
map \p :CtrlPCmdPalette<CR>
let g:ctrlp_cmdpalette_execute = 1

" Ignore some folders and files for CtrlP indexing
let g:ctrlp_custom_ignore = {
  \ 'dir': '\.git$\|\.yardoc\|public$|log\|tmp$',
  \ 'file': '\.so$\|\.dat$|\.DS_Store$'
  \ }

let g:ctrlp_working_path_mode = 'ra'
let g:ctrlp_show_hidden = 0

if has('win32')
  set wildignore+=*\\.git\\*,*\\.hg\\*,*\\.svn\\*
  let g:ctrlp_user_command = 'dir %s /-n /b /s /a-d'
else
  set wildignore+=*/.git/*,*/.hg/*,*/.svn/*
endif

let g:ctrlp_match_func = { 'match': 'pymatcher#PyMatch' }

" ========================================================================
" => TMUX NAVIGATOR
" ========================================================================
let g:tmux_navigator_save_on_switch = 1

" ========================================================================
" => GOLDENVIEW
" ========================================================================
let g:goldenview__enable_default_mapping = 0
" 1. split to tiled windows
nmap <silent>\\ <Plug>GoldenViewSplit

" 2. quickly switch current window with the main pane
" and toggle back
nmap <silent><F8> <Plug>GoldenViewSwitchMain
nmap <silent><S-F8> <Plug>GoldenViewSwitchToggle

" 3. jump to next and previous window
" nmap <silent><C-N> <Plug>GoldenViewNext
" nmap <silent><C-P> <Plug>GoldenViewPrevious

" ========================================================================
" => UNDOTREE
" ========================================================================
nnoremap <F9> :UndotreeToggle<CR>

" ========================================================================
" => VIMSHELL
" ========================================================================
nmap <silent><S-s> :vnew \| :VimShell zsh<CR>

" ========================================================================
" => VIM-MONSTER
" ========================================================================
" Use neocomplete.vim
let g:neocomplete#sources#omni#input_patterns = {
\   "ruby" : '[^. *\t]\.\w*\|\h\w*::',
\}

" Set async completion.
let g:monster#completion#rcodetools#backend = "async_rct_complete"

" Use neocomplete.vim
let g:neocomplete#force_omni_input_patterns = {
\   'ruby' : '[^. *\t]\.\|\h\w*::',
\}

" ========================================================================
" => COLOR CHANGES/SCHEMES & FONT
" ========================================================================

" Proper Solarized colors with t_Co=256
" let g:solarized_termcolors=256

set t_Co=256
set background=dark
colorscheme base16-default
set guifont=Sauce\ Code\ Powerline\ Bold:h14

hi LineNr                    ctermfg=green   ctermbg=black
hi NERDTreeCWD               ctermfg=white
hi NERDTreeLink              ctermfg=blue
hi NERDTreeExecFile          ctermfg=green
hi SyntasticStyleWarningSign ctermfg=yellow  ctermbg=black
hi SyntasticStyleErrorSign   ctermfg=red     ctermbg=black
hi SyntasticWarningSign      ctermfg=yellow  ctermbg=black
hi SyntasticErrorSign        ctermfg=red     ctermbg=black
hi SignColumn                ctermbg=black   ctermbg=black
hi GitGutterAdd              ctermfg=green   ctermbg=black
hi GitGutterChange           ctermfg=yellow  ctermbg=black
hi GitGutterDelete           ctermfg=red     ctermbg=black
hi GitGutterChangeDelete     ctermfg=blue    ctermbg=232
hi vertsplit                 ctermfg=green   ctermbg=green
hi Pmenu                                     ctermbg=238
hi ColorColumn                               ctermbg=238
hi CursorLine                                ctermbg=238
hi Folded                                    ctermbg=black
hi Statusline                ctermfg=white   ctermbg=blue
hi WildMenu                  ctermfg=black
hi Visual                                    ctermbg=238
hi vimTodo                   ctermfg=black   ctermbg=yellow
hi clear SignColumn

" ========================================================================
" => STATUSLINE
" ========================================================================
" Custom status line
set statusline=%f   " Path to the file in the buffer
set statusline+=%m  " Modified flag
set statusline+=%5{v:register} "Which active register
set statusline+=%=  " Align to the right from now on
set statusline+=[%{fugitive#statusline()}]   " Current branch
set statusline+=\ \  " Blank space
set statusline+=%y   " Type of file in the buffer
set statusline+=%5l  " Current line
set statusline+=/    " Slash
set statusline+=%-5L " Total lines
set statusline+=%p%% " Percentage through the file

" Highlight status bar when in insert mode
if version >= 700
  au InsertEnter * hi StatusLine ctermfg=235 ctermbg=2
  au InsertLeave * hi StatusLine ctermfg=white ctermbg=blue
endif

" ========================================================================
" => FUNCTIONS
" ========================================================================
" Delete trailing whitespace on save, taken from eddie blundell vimrc
func! DeleteTrailingWS()
    exe "normal mz"
    %s/\s\+$//ge
    exe "normal `z"
endfunc

" vim:foldmethod=marker:foldlevel=0
