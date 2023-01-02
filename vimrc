" vim:foldmethod=marker:foldlevel=0

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
set undodir=&undodir

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

" ------------------"
" => AUTOCMD        "
" ------------------"

if has("autocmd")
  " General autocmds e.g. autosaving file, reload vim config
  augroup general " {{{
    autocmd!
    " Reload vimrc when edited
    autocmd BufWritePost .vimrc,.vimrc.local,init.vim,_vimrc
      \ source % | if has('gui_running') | source % | endif

    " Reload dotfiles/vim/config.vim when sources/* files are edited
    " autocmd BufWritePost autocmds.vim,colors.vim,config.vim,core.vim,folds.vim,
    "   \functions.vim,mappings.vim,plugins.vim,plugins_config.vim,statusline.vim,
    "   \tabline.vim source %

    " Change working directory to current file's directory
    " autocmd BufEnter * lcd %:p:h

    " Save on losing focus i.e. tabbing away from vim
    autocmd FocusLost * :wa

    " Unset paste on InsertLeave
    autocmd InsertLeave * silent! set nopaste

    " Automatically open quickfix window after any grep invocation
    autocmd QuickFixCmdPost *grep* cwindow

    " Update file changes automatically (requires 'set autoread')
    " Makes AutoReadWatch plugin unnecessary
    autocmd FocusGained,BufEnter * checktime

    " Auto-resize splits when Vim gets resized
    autocmd VimResized * wincmd =
  augroup END " }}}

  " Set filetypes and related syntax
  augroup syntax_filetype_settings " {{{
    autocmd!
    autocmd BufRead,BufNewFile *.h,*.c set filetype=c.doxygen

    autocmd BufNewFile,BufRead *.rb,*.rbw,*.gemspec setlocal filetype=ruby

    autocmd FileType asm,s,S setlocal syntax=avr.vim
    autocmd BufRead,BufNewFile *.asm,*.s,*.S set syntax=avr.vim
  augroup END " }}}

  " Mark filetype on BufLeave. Makes it easy to go back to latest buffer of
  " [filetype].
  " NOTE: maybe change mC to *.c filetypes and mJ to *.java filetypes ??
  augroup mark_filetype " {{{
    autocmd!
    autocmd BufLeave *.css,*.less,*scss normal! mC
    autocmd BufLeave *.html             normal! mH
    autocmd BufLeave *.js               normal! mJ
    autocmd BufLeave *.c,*.cpp          normal! mC
    autocmd BufLeave *.h                normal! mH
    autocmd BufLeave *.java             normal! mJ
    autocmd BufLeave *.py               normal! mP
    autocmd BufLeave *.rb               normal! mR
    autocmd BufLeave *.ex,*.exs         normal! mE
    autocmd BufLeave *.go               normal! mG
    autocmd BufLeave *.md               normal! mM
    autocmd BufLeave *csv               normal! mC
    autocmd BufLeave vimrc,*.vim        normal! mV
  augroup END " }}}

  " Plugin related autocmds
  augroup plugins " {{{
    autocmd!
  augroup END " }}}

  " Set omnifunc by filetype
  augroup completions " {{{
    autocmd!
  augroup END " }}}

  " Only show number/relativenumber in NORMAL mode. Hide in INSERT mode.
  " Simlarly for WinEnter/Leave; FocusGained/Lost events.
  augroup relativize " {{{
    autocmd!

    function! Relativize(v)
      " let &number = a:v
      if &number
        let &relativenumber = a:v
      endif
    endfunction

    autocmd BufWinEnter,FocusGained,InsertLeave,WinEnter * call Relativize(1)
    autocmd BufWinLeave,FocusLost,InsertEnter,WinLeave * call Relativize(0)
  augroup END " }}}

  " Linting
  augroup Linting " {{{
    autocmd!
    autocmd QuickFixCmdPost [^l]* cwindow
  augroup END " }}}
endif

" ------------------"
" => COMMANDS       "
" ------------------"

" :Chomp trailing whitespace
command! Chomp silent! normal! :%s/\s\+$//<CR>

" Split XML/HTML from a single-line to multi-line
" command! HTMLSplit normal! cit<CR><C-r>"<CR><ESC>
" command! HTMLSplit normal! :s;>\s*<;>\r<;g<CR>='[

" :SwapLine [line] will swap the current line with the given line number.
" NOTE: :SwapLine will overwrite the line below if given a count that is the
" same as the line number of the current line.
command! -count SwapLine silent! normal! msyy<count>ggPjdd`sVpms

" :SwapRel{Next,Prev} will swap lines relative to the current line
command! -count SwapRelNext silent! normal! msyy<count>jPjdd`sVpms
command! -count SwapRelPrev silent! normal! msyy<count>kpkdd`sVpms

" :Swap{Next,Prev}. Swaps the current line with the next/previous line
command! SwapNext silent! normal! :SwapRelNext 1<CR>
command! SwapPrev silent! normal! :SwapRelPrev 1<CR>

" Scroll/cursor bind the current window and the previous window
" So they move together like in vimdiff
command! BindOn set scrollbind cursorbind | wincmd p |
  \ set scrollbind cursorbind | wincmd p
command! BindOff set noscrollbind nocursorbind | wincmd p |
  \ set noscrollbind nocursorbind | wincmd p

" Creates a nice underline
command! Underline silent! normal! yypVr-

" ------------------"
" => FOLDS SETTINGS "
" ------------------"

" NOTE: The below set of options allows for automatic opening and closing of
" folds as you move through them.
" To disable set 'nofoldenable' or set the foldlevel to a high number i.e. foldlevel=99.
" Moving between folds with 'zj' and 'zk'.

" set foldclose=all " Close folds if you leave them in any way
" set foldcolumn=0 " Show the foldcolumn
" set foldenable " Turn on folding
" set foldlevel=0 " Autofold everything by default
" set foldmethod=marker " Fold on the marker '{' x3
" set foldnestmax=1 " I only like to fold outer functions
" set foldopen=all " Open folds if you touch them in any way

" Use [of, ]of, =of to enable/disable/toggle the automatic closing/opening of folds.
fu! s:open_folds(action) abort
    if a:action ==# 'is_active'
        return exists('s:open_folds')
    elseif a:action ==# 'enable' && !exists('s:open_folds')
        let s:open_folds = {
        \                    'close'   : &foldclose,
        \                    'column'  : &foldcolumn,
        \                    'enable'  : &foldenable,
        \                    'level'   : &foldlevel,
        \                    'method'  : &foldmethod,
        \                    'nestmax' : &foldnestmax,
        \                    'open'    : &foldopen,
        \                  }
        set foldclose=all
        set foldcolumn=1
        set foldenable
        set foldlevel=0
        set foldmethod=marker
        set foldnestmax=1
        set foldopen=all
        echo '[auto open folds] ON'
    elseif a:action ==# 'disable' && exists('s:open_folds')
        for op in keys(s:open_folds)
            exe 'let &fold'.op.' = s:open_folds.'.op
        endfor
        unlet! s:open_folds
        echo '[auto open folds] OFF'
    endif
endfu

nnoremap <silent> [of :<c-u>call <sid>open_folds('enable')<cr>
nnoremap <silent> ]of :<c-u>call <sid>open_folds('disable')<cr>
nnoremap <silent> =of :<c-u>call <sid>open_folds(<sid>open_folds('is_active') ?
  \ 'disable' : 'enable')<cr>

" ------------------"
" => FUNCTIONS      "
" ------------------"

" :A
function! s:a() " {{{
  let name = expand('%:r')
  let ext = tolower(expand('%:e'))
  let sources = ['c', 'cc', 'cpp', 'cxx']
  let headers = ['h', 'hh', 'hpp', 'hxx']
  for pair in [[sources, headers], [headers, sources]]
    let [set1, set2] = pair
    if index(set1, ext) >= 0
      for h in set2
        let aname = name.'.'.h
        for a in [aname, toupper(aname)]
          if filereadable(a)
            execute 'e' a
            return
          end
        endfor
      endfor
    endif
  endfor
endfunction " }}}
" command! A call s:a()

" Delete trailing whitespace on save, taken from eddie blundell vimrc
" getpos() returns an array of [?, ROW, COL, ?]
" The 'if' checks that the 'z' mark is not set in the current row already.
" Otherwise errors may occur (this is due to conflicts with vim-signature).
func! DeleteTrailingWS() " {{{
  if getpos("'z")[1] != line(".")
    exe "normal mz"
  endif
    %s/\s\+$//ge
    exe "normal `z"
endfunc " }}}
nnoremap ,ws :call DeleteTrailingWS()<CR>:w<CR>

" Follow symlinks when opening a file
" NOTE: this happens with directory symlinks anyway (due to Vim's chdir/getcwd
" magic when getting filenames).
" Sources:
" - github.com/tpope/vim-fugitive/issues/147#issuecomment-7572351
" - reddit.com/r/vim/comments/yhsn6/is_it_possible_to_work_around_the_symlink_bug/c5w91qw
function! MyFollowSymlink(...) " {{{
  if exists('w:no_resolve_symlink') && w:no_resolve_symlink
    return
  endif
  let fname = a:0 ? a:1 : expand('%')
  if fname =~ '^\w\+:/'
    " do not mess with 'fugitive://' etc
    return
  endif
  let fname = simplify(fname)

  let resolvedfile = resolve(fname)
  if resolvedfile == fname
    return
  endif
  let resolvedfile = fnameescape(resolvedfile)
  echohl WarningMsg | echomsg 'Resolving symlink' fname '=>' resolvedfile | echohl None
  " exec 'noautocmd file ' . resolvedfile
  " XXX: problems with AutojumpLastPosition: line("'\"") is 1 always.
  exec 'file ' . resolvedfile
endfunction " }}}
" command! FollowSymlink call MyFollowSymlink()

" Platform idenfitication {{{
silent function! OSX()
    return has('macunix')
endfunction

silent function! LINUX()
    return has('unix') && !has('macunix') && !has('win32unix')
endfunction

silent function! WINDOWS()
    return  (has('win16') || has('win32') || has('win64'))
endfunction

silent function! UNIXLIKE()
    return !WINDOWS()
endfunction

silent function! FREEBSD()
  let s:uname = system("uname -s")
  return (match(s:uname, 'FreeBSD') >= 0)
endfunction
" }}}

" GitBranch for StatusLine
function! GitBranch() " {{{
  try
    if has('unix')
      return system("git rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '\n'")
    elseif has('win32')
      return '' "system("git rev-parse --abrev-ref HEAD")
    endif
  catch
    return ''
  endtry
endfunction

function! StatuslineGit()
  let l:branchname = GitBranch()
  return strlen(l:branchname) > 0 ? ' '.l:branchname.' ' : ''
  " return strlen(l:branchname) > 0 ? '  '.l:branchname.' ' : ''
endfunction
" }}}

" Returns whether inside a Rails Project
" NOTE: this may have been causing my startup problems
function! InRailsProject() " {{{
  if !has('nvim')
    return 0
  endif
  return strlen(system("test -f \"./config/application.rb\" && ag \"require 'rails/all'\"")) > 0 ? 1 : 0
endfunction
" }}}

" [Kwbd] A Better :bd - taken from:
"   http://vim.wikia.com/wiki/Deleting_a_buffer_without_closing_the_window
" delete the buffer; keep windows; create a scratch buffer if no buffers left
function! s:Kwbd(kwbdStage) " {{{
  if(a:kwbdStage == 1)
    if(!buflisted(winbufnr(0)))
      bd!
      return
    endif
    let s:kwbdBufNum = bufnr("%")
    let s:kwbdWinNum = winnr()
    windo call s:Kwbd(2)
    execute s:kwbdWinNum . 'wincmd w'
    let s:buflistedLeft = 0
    let s:bufFinalJump = 0
    let l:nBufs = bufnr("$")
    let l:i = 1
    while(l:i <= l:nBufs)
      if(l:i != s:kwbdBufNum)
        if(buflisted(l:i))
          let s:buflistedLeft = s:buflistedLeft + 1
        else
          if(bufexists(l:i) && !strlen(bufname(l:i)) && !s:bufFinalJump)
            let s:bufFinalJump = l:i
          endif
        endif
      endif
      let l:i = l:i + 1
    endwhile
    if(!s:buflistedLeft)
      if(s:bufFinalJump)
        windo if(buflisted(winbufnr(0))) | execute "b! " . s:bufFinalJump | endif
      else
        enew
        let l:newBuf = bufnr("%")
        windo if(buflisted(winbufnr(0))) | execute "b! " . l:newBuf | endif
      endif
      execute s:kwbdWinNum . 'wincmd w'
    endif
    if(buflisted(s:kwbdBufNum) || s:kwbdBufNum == bufnr("%"))
      execute "bd! " . s:kwbdBufNum
    endif
    if(!s:buflistedLeft)
      set buflisted
      set bufhidden=delete
      set buftype=
      setlocal noswapfile
    endif
  else
    if(bufnr("%") == s:kwbdBufNum)
      let prevbufvar = bufnr("#")
      if(prevbufvar > 0 && buflisted(prevbufvar) && prevbufvar != s:kwbdBufNum)
        b #
      else
        bn
      endif
    endif
  endif
endfunction " }}}
command! Bdelete call s:Kwbd(1)
noremap <Leader>d :Bdelete<CR>

" https://gist.github.com/romainl/047aca21e338df7ccf771f96858edb86
" Provides a prompt for each of the commands listed below.
" Make list-like commands more intuitive.
" function! CCR() " {{{
"     let cmdline = getcmdline()
"     if cmdline =~ '\v\C^(ls|files|buffers)'
"         " like :ls but prompts for a buffer command
"         return "\<CR>:b"
"     elseif cmdline =~ '\v\C/(#|nu|num|numb|numbe|number)$'
"         " like :g//# but prompts for a command
"         return "\<CR>:"
"     elseif cmdline =~ '\v\C^(dli|il)'
"         " like :dlist or :ilist but prompts for a count for :djump or :ijump
"         return "\<CR>:" . cmdline[0] . "j  " . split(cmdline, " ")[1] . "\<S-Left>\<Left>"
"     elseif cmdline =~ '\v\C^(cli|lli)'
"         " like :clist or :llist but prompts for an error/location number
"         return "\<CR>:sil " . repeat(cmdline[0], 2) . "\<Space>"
"     elseif cmdline =~ '\C^old'
"         " like :oldfiles but prompts for an old file to edit
"         set nomore
"         return "\<CR>:sil se more|e #<"
"     elseif cmdline =~ '\C^changes'
"         " like :changes but prompts for a change to jump to
"         set nomore
"         return "\<CR>:sil se more|norm! g;\<S-Left>"
"     elseif cmdline =~ '\C^ju'
"         " like :jumps but prompts for a position to jump to
"         set nomore
"         return "\<CR>:sil se more|norm! \<C-o>\<S-Left>"
"     elseif cmdline =~ '\C^marks'
"         " like :marks but prompts for a mark to jump to
"         return "\<CR>:norm! `"
"     elseif cmdline =~ '\C^undol'
"         " like :undolist but prompts for a change to undo
"         return "\<CR>:u "
"     else
"         return "\<CR>"
"     endif
" endfunction
" cnoremap <expr> <CR> CCR()
" }}}
" https://www.reddit.com/r/vim/comments/7iy03o/you_aint_gonna_need_it_your_replacement_for/dr2qo4k/
" The below is a new version of the above CCR() function, taken from the above Reddit post.
cnoremap <expr> <CR> <SID>CCR() " {{{
function! s:CCR()
    command! -bar Z silent set more|delcommand Z
    if getcmdtype() == ":"
        let cmdline = getcmdline()
            if cmdline =~ '\v\C^(dli|il)' | return "\<CR>:" . cmdline[0] . "jump   " . split(cmdline, " ")[1] . "\<S-Left>\<Left>\<Left>"
        elseif cmdline =~ '\v\C^(cli|lli)' | return "\<CR>:silent " . repeat(cmdline[0], 2) . "\<Space>"
        elseif cmdline =~ '\C^changes' | set nomore | return "\<CR>:Z|norm! g;\<S-Left>"
        elseif cmdline =~ '\C^ju' | set nomore | return "\<CR>:Z|norm! \<C-o>\<S-Left>"
        elseif cmdline =~ '\v\C(#|nu|num|numb|numbe|number)$' | return "\<CR>:"
        elseif cmdline =~ '\C^ol' | set nomore | return "\<CR>:Z|e #<"
        elseif cmdline =~ '\v\C^(ls|files|buffers)' | return "\<CR>:b"
        elseif cmdline =~ '\C^marks' | return "\<CR>:norm! `"
        elseif cmdline =~ '\C^undol' | return "\<CR>:u "
        else | return "\<CR>" | endif
    else | return "\<CR>" | endif
endfunction
" }}}

" Sets the arglist (:args) to contain each file referenced in the quicklist.
" This is useful for when using a Vim that doesn't include :cdo/:ldo.
function! QuickfixFilenames() " {{{
  " Building a hash ensures we get each buffer only once
  let buffer_numbers = {}
  for quickfix_item in getqflist()
    let buffer_numbers[quickfix_item['bufnr']] = bufname(quickfix_item['bufnr'])
  endfor
  return join(map(values(buffer_numbers), 'fnameescape(v:val)'))
endfunction
command! -nargs=0 -bar Qargs execute 'args' QuickfixFilenames()
" }}}

" Perform replace on all results in the quickfix from the last search.
function! QFReplace(bang, replace) " {{{
  let l:flag = 'ge'
  if !a:bang
    let l:flag .= 'c'
  endif
  let replace = escape(a:replace, '/\&~')
  execute 'cdo %s//' . replace . '/g' . l:flag
endfunction " }}}
command! -bang -nargs=1 CReplace call QFReplace(<bang>0,<f-args>)
nnoremap ,gr :call QFReplace(1, input("Replace '".expand('<C-R>/')."' with: "))<CR>

function! GetVisualSelection() " {{{
    " Why is this not a built-in Vim script function?!
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return ''
    endif
    let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][column_start - 1:]
    return join(lines, "\n")
endfunction " }}}

" Search Suggestions AutoComplete
function! s:search_mode_start()
    cnoremap <tab> <c-f>a<c-n>
    let s:old_complete_opt = &completeopt
    set completeopt-=noinsert
endfunction

function! s:search_mode_stop()
    cunmap <tab>
    let &completeopt = s:old_complete_opt
endfunction

" Not available on Neovim version <= 0.2.2
" augroup search_mode
"   autocmd!
"   autocmd CmdlineEnter [/\?] call <SID>search_mode_start()
"   autocmd CmdlineLeave [/\?] call <SID>search_mode_stop()
" augroup END

" Window splitting / movement
" function! WinMove(key)
"     let t:curwin = winnr()
"     exec "wincmd ".a:key
"     if (t:curwin == winnr())
"         if (match(a:key,'[jk]'))
"             wincmd v
"         else
"             wincmd s
"         endif
"         exec "wincmd ".a:key
"     endif
" endfunction
" " NOTE: <C-h> mapping does not work (at least not on Neovim).
" noremap <silent> <C-h> :call WinMove('h')<CR>
" noremap <silent> <C-j> :call WinMove('j')<CR>
" noremap <silent> <C-k> :call WinMove('k')<CR>
" noremap <silent> <C-l> :call WinMove('l')<CR>

" ------------------"
" => COLOR SETTINGS "
" ------------------"

" set t_co=256
let hour = strftime("%H")
if 7 <= hour && hour < 18 " i.e. daytime
    set background=light
else
    set background=dark
endif

if has('unix')
  " Allow color schemes to do bright colors without forcing bold.
  if &t_Co == 8 && $TERM !~# '^linux\|^Eterm'
    set t_Co=16
  endif

  if (has("termguicolors"))
    set termguicolors
    silent! colorscheme desert
  else
    " Set 256 colorscheme.
    " Maybe some base16 one.
    colorscheme desert
  endif
elseif has('win32')
  " highlight CursorLine ctermfg=black ctermbg=white
  if has('nvim') || has('termguicolors')
    set termguicolors
  elseif has('gui_running')
    set guifont=Fira_Code_Retina:h10:W450:cANSI:qDRAFT
  endif
endif

"=================================================================
"   StatusLine:                                                  =
"=================================================================

" set statusline+=%(%{&paste?'\ p\ ':''}%)
" set statusline+=%(\ \ %{fugitive#head()}%)
" set statusline+=%([%n]%<\ %p%%\ ☰\ \ %l/%L\ \ :%c\ %)

" Dictionary: take mode() input -> longer notation of current mode
" mode() is defined by Vim
let g:currentmode={
      \'n' : 'Normal ',
      \'no' : 'N·Operator Pending ',
      \'v' : 'Visual ',
      \'V' : 'V·Line ',
      \'^V' : 'V·Block ',
      \'s' : 'Select ',
      \'S': 'S·Line ',
      \'^S' : 'S·Block ',
      \'i' : 'Insert ',
      \'R' : 'Replace ',
      \'Rv' : 'V·Replace ',
      \'c' : 'Command ',
      \'cv' : 'Vim Ex ',
      \'ce' : 'Ex ',
      \'r' : 'Prompt ',
      \'rm' : 'More ',
      \'r?' : 'Confirm ',
      \'!' : 'Shell ',
      \'t' : 'Terminal '
      \}


" Function: return current mode
" abort -> function will abort soon as error detected
function! ModeCurrent() abort " {{{
    let l:modecurrent = mode()
    " use get() -> fails safely, since ^V doesn't seem to register
    " 3rd arg is used when return of mode() == 0, which is case with ^V
    " thus, ^V fails -> returns 0 -> replaced with 'V Block'
    let l:modelist = toupper(get(g:currentmode, l:modecurrent, 'V·Block '))
    let l:current_status_mode = l:modelist
    return l:current_status_mode
endfunction " }}}

function! FileSize() abort " {{{
    let l:bytes = getfsize(expand('%p'))
    if (l:bytes >= 1024)
        let l:kbytes = l:bytes / 1025
    endif
    if (exists('kbytes') && l:kbytes >= 1000)
        let l:mbytes = l:kbytes / 1000
    endif

    if l:bytes <= 0
        return '0'
    endif

    if (exists('mbytes'))
        return l:mbytes . 'MB '
    elseif (exists('kbytes'))
        return l:kbytes . 'KB '
    else
        return l:bytes . 'B '
    endif
endfunction " }}}

function! ReadOnly() abort " {{{
  if &readonly || !&modifiable
    return ''
  else
    return ''
endfunction " }}}

" Statusline
set statusline=
set statusline+=\                  " Blank space
set statusline+=\ %{ModeCurrent()} " Show mode (normal/insert/etc.)
set statusline+=\                  " Blank space
set statusline+=%#PmenuSel#

set statusline+=\                  " Blank space
set statusline+=%t                 " Path to the file in the buffer
set statusline+=%h%w%m             " Modified flag
set statusline+=\                  " Blank space
set statusline+=%y                 " Type of file in the buffer
set statusline+=\                  " Blank space

set statusline+=%#LineNr#
set statusline+=%(%{&paste?'\ --PASTE--\ ':''}%)

" set statusline+=%(\ Q:%{substitute(len(getqflist()),'^0','','')}%)

set statusline+=%{StatuslineGit()} " Current branch"

set statusline+=%=                 " Align to the right from now on
set statusline+=\ \[%{&fileencoding?&fileencoding:&encoding},
set statusline+=\ %{&fileformat}\]

set statusline+=\                  " Blank space
set statusline+=%#PmenuSel#
set statusline+=\                  " Blank space

set statusline+=%l                 " Current line
set statusline+=/                  " Slash
set statusline+=%L                 " Total lines
set statusline+=:%v                " Virtual column number
set statusline+=\                  " Blank space
set statusline+=%p%%               " Percentage through the file
set statusline+=\

"=================================================================
"   TabLine:                                                     =
"=================================================================

function! MyBufLine() abort " {{{1
    let l:bl = '%#TablineFill#' " bg of tabline
    let l:bufs = s:Buffers()    " list of buffers
    let l:bufs_n = len(l:bufs)  " number of buffers in the list
    for l:b in l:bufs           " l:b is the 'current' buffer
        " do not show Terminal buffers in the buffer line
        if getbufvar(l:b, '&buftype') ==# 'terminal'
          continue
        endif

        " NOTE: The case where we have 1 buffer is checked in TLInit().

        " If more than 8, show only '[B] #numberOfBuffers'
        if l:bufs_n >=# 8
            let l:bl .= '%#TabLine# [B] ' . l:bufs_n . ' %#TabLineFill# '
            break
        endif

        let l:mod = (getbufvar(l:b, '&modified') ==# 1 ? ' +' : '')
        let l:name = (!empty(bufname(l:b)) ?
                    \   pathshorten(fnamemodify(bufname(l:b), ':.')) . l:mod :
                    \   '[No Name]'
                    \ )

        let l:bl .= (l:b ==# bufnr('%') ? '%#PmenuSel# ' . l:name :
                    \ '%#Folded# ' . l:name) . ' %#LineNr# '
    endfor

    let l:get_cwd = fnamemodify(getcwd(), ':p:~')
    if l:get_cwd !=# '~/'
        let l:cwd = len(l:get_cwd) >=# 15 ? pathshorten(fnamemodify(l:get_cwd, ':p:~:h')) : l:get_cwd
        let l:bl .= '%=%#IncSearch# ' . l:cwd . ' '
    else
        " let l:bl .= '%=%#IncSearch# ' . '$HOME' . ' '
        let l:bl .= '%=%#IncSearch# ' . pathshorten(getcwd()) . ' '
    endif

    return l:bl
endfunction
" 1}}}

function! MyTabLine() abort " {{{1
    " :h setting-tabline

    let l:tl = '%#TabLineSel# [T] %#TabLineFill#'
    for i in range(tabpagenr('$'))
        let l:i = i + 1
        let l:tl .= (l:i ==# tabpagenr()) ?
                    \ ' %#PmenuSel#' : ' %#Folded#'
        " Set the tab page number (for mouse clicks)
        let l:tl .= '%' . l:i . 'T '
        Get working directory (Use tabpagecd if present, otherwise use
        getcwd()).
        if !empty(gettabvar(l:i, 'cwd'))
            let l:tl .= tabpagenr('$') >=# 5 ?
                        \ fnamemodify(gettabvar(l:i, 'cwd'), ':t') :
                        \ pathshorten(fnamemodify(gettabvar(l:i, 'cwd'), ':~'))
        else
            let l:tl .= tabpagenr('$') >=# 5 ?
                        \ fnamemodify(getcwd(), ':t') :
                        \ pathshorten(fnamemodify(getcwd(), ':~'))
        endif
        let l:tl .= '%' . l:i . 'X ⨉'
        " Fill with TabLineFill and reset tab page nr
        let l:tl .= ' %#TabLineFill#%T'
    endfor

    let l:get_cwd = fnamemodify(getcwd(), ':p:~')
    if l:get_cwd !=# '~/'
        let l:cwd = len(l:get_cwd) >=# 15 ? pathshorten(fnamemodify(l:get_cwd, ':p:~:h')) : l:get_cwd
        let l:tl .= '%=%#IncSearch# ' . l:cwd . ' '
    else
        " let l:bl .= '%=%#IncSearch# ' . '$HOME' . ' '
        let l:tl .= '%=%#IncSearch# ' . pathshorten(getcwd()) . ' '
    endif

    return l:tl
endfunction
" 1}}}

function! TLInit() abort " {{{1
    let l:bufs = s:Buffers()
    " NOTE: I commented this out cos I want to ALWAYS show tabline
    " if len(s:Buffers()) ==# 1 && getcwd() ==# $HOME
    "     set showtabline=0
    "     return
    " endif
    set tabline=
    set showtabline=2
    if tabpagenr('$') ==# 1
        let l:bufs = l:bufs
        let &showtabline = len(l:bufs) ># 1 ? 2 : &showtabline
        set tabline=%!MyBufLine()
    else
        set showtabline=2
        set tabline=%!MyTabLine()
    endif
endfunction
" 1}}}

" ========== HELPERS ========================================

function! s:Buffers() abort " {{{1
    return filter(range(1, bufnr('$')), 'buflisted(v:val)')
endfunction
" 1}}}

" ========== INITIALIZE ========================================

" {{{1
hi! link TablineSel StatusLine
augroup TabBufLine
    autocmd!
    autocmd BufAdd,BufDelete,BufWinEnter,TabNew,TabClosed,VimEnter *
                \ call TLInit()
augroup END
call TLInit()
" 1}}}

"=================================================================
"   Mappings:                                                    =
"=================================================================

" <leader> key
let mapleader      = " "
let g:mapleader    = " "
let maplocalleader = "\\"

" alternate escapes
inoremap jj <esc>

" move vertically by visual line
" nnoremap j gj
" nnoremap k gk

" Vertical movement with cursor center of screen
" nnoremap j gjzz
" nnoremap k gkzz

" move to begging/end of line
map 0 ^

" unmap arrow keys
nnoremap <up> <nop>
nnoremap <down> <nop>
nnoremap <left> <nop>
nnoremap <right> <nop>

" Easy pane resizing
nnoremap <Up> <C-w>+
nnoremap <Down> <C-w>-
nnoremap <Left> <C-w><
nnoremap <Right> <C-w>>

" Buffer navigation
noremap <leader>p :bp<CR>
noremap <leader>n :bn<CR>
nnoremap <S-right> <ESC>:bn<CR>
nnoremap <S-left> <ESC>:bp<CR>

" Close buffer (NOTE: see functions.vim#s:Kwbd()
" noremap <leader>d :bd<CR>

" Retain visual selection after indenting
vnoremap < <gv
vnoremap > >gv
vnoremap <S-Tab> <gv
vnoremap <Tab> >gv

" Make Y behave like other capitals
nnoremap Y y$

" turn off search highlight
nnoremap <silent>  <space> :nohlsearch<CR>

" changes the default Vim regexes to sane/regular regex. or something.
nnoremap / /\v
vnoremap / /\v
nnoremap ? ?\v
vnoremap ? ?\v
nnoremap :s/ :s/\v

set gdefault " defaults substitutions globally on lines

" center screen when scrolling search results
nnoremap n nzvzz
nnoremap N Nzvzz
" not in use, slash.vim overwrites these
" nnoremap * *zvzz
" nnoremap # #zvzz

" Have the help split vertically instead of the default horizontally.
" cnoremap help vert help
cabbrev h vert h

if (has('nvim'))
  " Quit
  inoremap <C-Q> <ESC>:q<CR>
  nnoremap <C-Q> :q<CR>
  vnoremap <C-Q> <ESC>
endif

" Readline-style key bindings in command-line (excerpt from tpope/rsi.vim)
inoremap        <C-A> <C-O>^
inoremap   <C-X><C-A> <C-A>
cnoremap        <C-A> <Home>
cnoremap   <C-X><C-A> <C-A>

inoremap <expr> <C-B> getline('.')=~'^\s*$'&&col('.')>strlen(getline('.'))?"0\<Lt>C-D>\<Lt>Esc>kJs":"\<Lt>Left>"
cnoremap        <C-B> <Left>

inoremap <expr> <C-D> col('.')>strlen(getline('.'))?"\<Lt>C-D>":"\<Lt>Del>"
cnoremap <expr> <C-D> getcmdpos()>strlen(getcmdline())?"\<Lt>C-D>":"\<Lt>Del>"

inoremap <expr> <C-E> col('.')>strlen(getline('.'))<bar><bar>pumvisible()?"\<Lt>C-E>":"\<Lt>End>"

inoremap <expr> <C-F> col('.')>strlen(getline('.'))?"\<Lt>C-F>":"\<Lt>Right>"
cnoremap <expr> <C-F> getcmdpos()>strlen(getcmdline())?&cedit:"\<Lt>Right>"

if empty(mapcheck('<C-G>', 'c'))
  cmap <script> <C-G> <C-C>
endif

noremap! <expr> <SID>transposition getcmdpos()>strlen(getcmdline())?"\<Left>":getcmdpos()>1?'':"\<Right>"
noremap! <expr> <SID>transpose "\<BS>\<Right>".matchstr(getcmdline()[0 : getcmdpos()-2], '.$')
cmap <script> <C-T> <SID>transposition<SID>transpose

" #!! | Shebang
inoreabbrev <expr> #!! "#!/usr/bin/env" . (empty(&filetype) ? '' : ' '.&filetype)

" Buffer navigation
nnoremap gb :ls<CR>:buffer<Space>
nnoremap gB :ls<CR>:sbuffer<Space>
nnoremap ,b :buffer *
nnoremap ,B :sbuffer *
nnoremap ,a :b#<CR>
nnoremap ,A :sb#<CR>

" File navigation
nnoremap ,f :find *
nnoremap ,s :sfind *
nnoremap ,v :vert sfind *
nnoremap ,t :tabfind *
nnoremap ,F :find <C-R>=fnameescape(expand('%:p:h')).'/**/*'<CR>
nnoremap ,S :sfind <C-R>=fnameescape(expand('%:p:h')).'/**/*'<CR>
nnoremap ,V :vert sfind <C-R>=fnameescape(expand('%:p:h')).'/**/*'<CR>
nnoremap ,T :tabfind <C-R>=fnameescape(expand('%:p:h')).'/**/*'<CR>

" Quick search/replace
" SnR word under cursor in the current line
nnoremap <Space><Space> :'{,'}s/\<<C-r>=expand('<cword>')<CR>\>/

" SnR word under cursor in the current file
nnoremap <Space>%       :%s/\<<C-r>=expand('<cword>')<CR>\>/

" Sharing snippets
if has('unix') && executable('xclip')
  command! -range=% IX  <line1>,<line2>w !curl -F 'f:1=<-' ix.io | tr -d '\n' | xclip -i -selection clipboard
  " command! -range=% SP  <line1>,<line2>w !curl -F 'sprunge=<-' http://sprunge.us | tr -d '\n' | xclip -i -selection clipboard
  " command! -range=% CL  <line1>,<line2>w !curl -F 'clbin=<-' https://clbin.com | tr -d '\n' | xclip -i -selection clipboard
  " command! -range=% VP  <line1>,<line2>w !curl -F 'text=<-' http://vpaste.net | tr -d '\n' | xclip -i -selection clipboard
  " command! -range=% TB <line1>,<line2>w !nc termbin 9999 | tr -d '\n' | xclip -i -selection clipboard
endif

" Autoexpansion brackets ala delimitmate
" inoremap (<CR> (<CR>)<Esc>O
" inoremap {<CR> {<CR>}<Esc>O
" inoremap {; {<CR>};<Esc>O
" inoremap {, {<CR>},<Esc>O
" inoremap [<CR> [<CR>]<Esc>O
" inoremap [; [<CR>];<Esc>O
" inoremap [, [<CR>],<Esc>O

" Scratch buffer - See functions.vim for a better version ScratchEdit() + related cmds.
" command! SCV vnew | setlocal nobuflisted buftype=nofile bufhidden=wipe noswapfile
" command! SC new | setlocal nobuflisted buftype=nofile bufhidden=wipe noswapfile

" Symbol-based navigation
nnoremap ,j :tjump /
nnoremap ,p :ptjump /

nnoremap ,i :ilist /
nnoremap [I [I:ijump   <C-r><C-w><S-Left><Left><Left>
nnoremap ]I ]I:ijump   <C-r><C-w><S-Left><Left><Left>

nnoremap ,d :dlist /
nnoremap [D [D:djump   <C-r><C-w><S-Left><Left>
nnoremap ]D ]D:djump   <C-r><C-w><S-Left><Left>

" Like '<C-r><C-w>' but for the line under the cursor.
cnoremap <C-r><C-l> <C-r>=getline('.')<CR>

"=================================================================
"   Plugins:                                                     =
"=================================================================
" Install vim-plug if not found
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . 'autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  " autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

" NOTE: Don't load plugins if plugin manager/plugins not installed.
if ! empty(globpath(&rtp, 'autoload/plug.vim'))
  " Plugins will be downloaded under the specified directory.
  call plug#begin(has('nvim') ? stdpath('data') . '/plugged' : '~/.vim/plugged')

  " Declare the list of plugins.
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
  Plug 'junegunn/seoul256.vim'

  Plug 'junegunn/vim-peekaboo'
  Plug 'junegunn/vim-easy-align', { 'on': ['<Plug>(EasyAlign)', 'EasyAlign'] }
  Plug 'junegunn/fzf',            { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'
  Plug 'junegunn/vim-slash'
  Plug 'tpope/vim-fugitive'
  Plug 'tpope/vim-sensible'
  Plug 'tpope/vim-endwise'
  Plug 'tpope/vim-eunuch'
  Plug 'tpope/vim-surround'
  Plug 'tpope/vim-unimpaired'
  Plug 'tpope/vim-commentary'
  Plug 'tpope/vim-repeat'
  Plug 'tpope/vim-ragtag'
  Plug 'wellle/targets.vim'

  if has('unix')
    Plug 'christoomey/vim-tmux-navigator'
    Plug 'tmux-plugins/vim-tmux'
    Plug 'terryma/vim-smooth-scroll'
    Plug 'tpope/vim-vinegar' " NOTE: some errors with installing on Windows
  endif

  Plug 'henrik/vim-indexed-search'
  Plug 'romainl/vim-qf'
  Plug 'romainl/vim-qlist'
  Plug 'kshenoy/vim-signature' " displays marks
  Plug 'chrisbra/vim-diff-enhanced'
  Plug 'haya14busa/vim-asterisk'
  Plug 'Yggdroot/indentLine'

  Plug 'LnL7/vim-nix'

  call plug#end()

  "=================================================================
  "   Plugin Configs:                                                     =
  "=================================================================
  colorscheme palenight
endif
