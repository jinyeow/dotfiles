" Search in project - use if vim-grepper plugin is unavailable
" NOTE: Use in Linux only
" UPDATED: 21/06/20 13:14

if has('unix')

  if exists("g:loaded_rgaggrep") || &compatible " || v:version < 703 
    finish
  endif
  let g:loaded_rgaggrep = 1

  let s:save_cpo = &cpo
  set cpo&vim

  let [s:grep_prg, s:grep_format] = ['%s --smart-case --fixed-strings --vimgrep', '%f:%l:%c:%m,%f:%l:%m']
  if executable('rg')
    let &grepprg    = printf(s:grep_prg, 'rg')
    let &grepformat = s:grep_format
  elseif executable("ag")
    let &grepprg    = printf(s:grep_prg, 'ag')
    let &grepformat = s:grep_format
  else
    set grepprg='grep -rn $* *'
    let &grepformat = s:grep_format
  endif
  unlet! s:grep_prg s:grep_format

  command! -nargs=+ -complete=file_in_path -bar Grep  silent! grep! <args> | redraw!
  command! -nargs=+ -complete=file_in_path -bar LGrep silent! lgrep! <args> | redraw!

  nnoremap <silent> ,G :Grep <C-r><C-w><CR>

  " NOTE: This relies on GetVisualSelection() function defined in my functions.vim
  xnoremap <silent> ,G :<C-u>let cmd = "Grep " . shellescape(GetVisualSelection()) <bar>
                          \ call histadd("cmd", cmd) <bar>
                          \ execute cmd

  let &cpo = s:save_cpo

endif
