" vim:foldmethod=marker:foldlevel=0
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
    autocmd BufWritePost autocmds.vim,colors.vim,config.vim,core.vim,folds.vim,
      \functions.vim,mappings.vim,plugins.vim,plugins_config.vim,statusline.vim,
      \tabline.vim source %

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

    " NOTE: Causing some errors so I turned this off.
    " function! s:arw() " {{{
    "   if exists('g:loaded_autoreadwatch') && &modifiable
    "     :WatchForChangesQuietly
    "   endif
    " endfunction " }}}
    " autocmd BufEnter * call s:arw()
  augroup END " }}}

  " Set omnifunc by filetype
  augroup completions " {{{
    autocmd!
    " autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
    " autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
    " autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
    " autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
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
  " NOTE: check for 'make' utility first
  augroup Linting " {{{
    autocmd!
    autocmd BufWritePost *.rb silent make! <afile> | silent redraw!
    autocmd QuickFixCmdPost [^l]* cwindow
  augroup END " }}}
endif
