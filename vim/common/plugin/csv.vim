" Filetype plugin for editing CSV files.
" Version 2011-11-02 from http://vim.wikia.com/wiki/csv
if v:version < 700 || exists("g:loaded_csvplugin") || &compatible
  finish
endif
let g:loaded_csvplugin = 1

let s:save_cpo = &cpo
set cpo&vim

" Return number of characters (not bytes) in string.
function! s:CharLen(str)
  return strlen(substitute(a:str, '.', 'x', 'g'))
endfunction
 
" Display a warning message.
function! s:Warn(msg)
  echohl WarningMsg
  echo a:msg
  echohl NONE
endfunction
 
command! -nargs=1 Csv :call CSVH(<args>)
" --- Highlighting a column {{{
" Highlight a column in csv text.
" :Csv 1    " highlight first column
" :Csv 12   " highlight twelfth column
" :Csv 0    " switch off highlight
function! CSVH(colnr)
  if a:colnr > 1
    let n = a:colnr - 1
    execute 'match Keyword /^\([^,]*,\)\{'.n.'}\zs[^,]*/'
    execute 'normal! 0'.n.'f,'
  elseif a:colnr == 1
    match Keyword /^[^,]*/
    normal! 0
  else
    match
  endif
endfunction
command! -nargs=1 Csv :call CSVH(<args>)
nnoremap ,c :Csv<Space>
 
"}}}

let &cpo = s:save_cpo
