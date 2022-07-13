if exists("g:indentLine_loaded")
  let g:indentLine_enabled = 0

  " nnoremap <silent> [ig :IndentLinesEnable<CR>
  " nnoremap <silent> ]ig :IndentLinesDisable<CR>
  nnoremap <silent> =ig :IndentLinesToggle<CR>
endif
