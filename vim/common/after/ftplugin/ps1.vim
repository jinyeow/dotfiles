setlocal tabstop=4
setlocal softtabstop=4
setlocal shiftwidth=4

setlocal textwidth=115

setlocal foldmethod=syntax

" Coc.nvim Settings
if exists('g:did_coc_loaded')
  " Execute Powershell
  nnoremap <F8> :CocCommand powershell.evaluateLine<cr>
  vnoremap <F8> :CocCommand powershell.evaluateSelection<cr>
  nnoremap <F5> :CocCommand powershell.execute<cr>

  noremap <F12> :CocCommand powershell.toggleTerminal<CR>
endif
