if exists("g:loaded_tmux_navigator") && v:version >= 700
  if has('unix')
    let g:tmux_navigator_save_on_switch = 1
    if has('nvim')
      nmap <silent> <BS> :<C-u>TmuxNavigateLeft<CR>
    endif

    " let g:tmux_navigator_no_mappings = 1
    " nnoremap <silent> <C-h> :TmuxNavigateLeft<cr>
    " nnoremap <silent> <C-j> :TmuxNavigateDown<cr>
    " nnoremap <silent> <C-k> :TmuxNavigateUp<cr>
    " nnoremap <silent> <C-l> :TmuxNavigateRight<cr>
    " nnoremap <silent> {Previous-Mapping} :TmuxNavigatePrevious<cr>
  endif
endif

