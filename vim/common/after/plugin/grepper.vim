if exists('g:loaded_grepper')
  if executable('rg')
    nnoremap ,gg :GrepperRg<Space>
    nnoremap ,ga :GrepperRg<Space><C-R><C-W><CR>
  elseif executable('ag')
    nnoremap ,gg :GrepperAg<Space>
    nnoremap ,ga :GrepperAg<Space><C-R><C-W><CR>
  else
    nnoremap ,gg :GrepperGrep<Space>
    nnoremap ,ga :GrepperGrep<Space><C-R><C-W><CR>
  endif

  nnoremap gs <Plug>(GrepperOperator)
  xnoremap gs <Plug>(GrepperOperator)
endif
