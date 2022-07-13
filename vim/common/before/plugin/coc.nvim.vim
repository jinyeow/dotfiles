let g:coc_global_extensions = [
      \ 'coc-lists',
      \ 'coc-powershell',
      \ 'coc-json',
      \ 'coc-tsserver',
      \ 'coc-html',
      \ 'coc-rust-analyzer'
      \ ]

" Install eslint/prettier based on whether they are installed in the local node_modules folder
if isdirectory('./node_modules') && isdirectory('./node_modules/prettier')
  let g:coc_global_extensions += ['coc-prettier']
endif

if isdirectory('./node_modules') && isdirectory('./node_modules/eslint')
  let g:coc_global_extensions += ['coc-eslint']
endif

