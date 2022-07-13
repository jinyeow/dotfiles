if exists("g:loaded_ridoc") || &compatible
  finish
endif
let g:loaded_ridoc = 1

let s:save_cpo = &cpo
set cpo&vim

function! RiDoc(str)
  let l:cmd = "new | setlocal nobuflisted buftype=nofile bufhidden=wipe noswapfile | r!ri --format"

  " NOTE: using vim-plugin-AnsiEsc with ri --format ansi for correct color
  if exists(':AnsiEsc')
    let l:cmd = l:cmd . " ansi " . shellescape(a:str)
    execute l:cmd
    execute "AnsiEsc"
  else
    let l:cmd = l:cmd . " markdown " . shellescape(a:str)
    execute l:cmd
  endif
  normal gg
endfunction

command! -nargs=1 RiDoc call RiDoc(<f-args>)

" nnoremap ,ri :RiDoc<Space>

augroup ridoc
  autocmd!
  autocmd Filetype ruby,eruby setlocal keywordprg=:RiDoc
augroup END

let &cpo = s:save_cpo
