if exists("g:loaded_qf") && v:version > 702
  let g:qf_mapping_ack_style = 1

  nnoremap <leader>qf <Plug>qf_qf_toggle
  nnoremap <leader>qq <Plug>qf_qf_stay_toggle
  nnoremap <leader>qp <Plug>(qf_qf_previous)
  nnoremap <leader>qn <Plug>(qf_qf_next)
  nnoremap <leader>qk <Plug>(qf_loc_previous)
  nnoremap <leader>qj <Plug>(qf_loc_next)
  " nnoremap <leader>q  <Plug>(qf_qf_switch)
  " nnoremap <leader>q  <Plug>(qf_qf_toggle)
  " nnoremap <leader>q  <Plug>(qf_qf_toggle_stay)
  " nnoremap <leader>q  <Plug>(qf_loc_toggle)
  " nnoremap <leader>q  <Plug>(qf_loc_toggle_stay)
  " nnoremap <leader>q  <Plug>(qf_older)
  " nnoremap <leader>q  <Plug>(qf_newer)
  " nnoremap <leader>q  <Plug>(qf_previous_file)
  " nnoremap <leader>q  <Plug>(qf_next_file)
endif
