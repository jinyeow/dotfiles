if exists('g:did_coc_loaded')
  " Some servers have issues with backup files, see #649
  set nobackup
  set nowritebackup

  " Give more space for displaying messages
  set cmdheight=2

  " Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
  " delays and poor user experience.
  set updatetime=300

  " Don't pass messages to |ins-completion-menu|
  set shortmess+=c

  " Always show the signcolumn, otherwise it would shift the text each time
  " diagnostics appear/become resolved.
  " if has("patch-8.1.1564")
  "   " Recently vim can merge signcolumn and number column into one
  "   set signcolumn=number
  " else
  "   set signcolumn=yes
  " endif

  " Use tab for trigger completion with characters ahead and navigate.
  " Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.
  inoremap <silent><expr> <TAB>
        \ pumvisible() ? "\<C-n>" :
        \ <SID>check_back_space() ? "\<TAB>" :
        \ coc#refresh()
  inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

  function! s:check_back_space() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~# '\s'
  endfunction

  autocmd! CompleteDone * if pumvisible() == 0 | pclose | endif

  " Use `[g` and `]g` to navigate diagnostics
  nmap <silent> [g <Plug>(coc-diagnostic-prev)
  nmap <silent> ]g <Plug>(coc-diagnostic-next)

  " Use K to show documentation in preview window
  nnoremap <silent> K :call <SID>show_documentation()<CR>

  function! s:show_documentation()
    if (index(['vim','help'], &filetype) >= 0)
      execute 'h '.expand('<cword>')
    else
      call CocAction('doHover')
    endif
  endfunction

  " Highlight the symbol and its references when holding the cursor.
  autocmd! CursorHold * silent call CocActionAsync('highlight')

  " GoTo code navigation.
  nmap <silent> gd <Plug>(coc-definition)
  nmap <silent> gy <Plug>(coc-type-definition)
  nmap <silent> gr <Plug>(coc-references)
  nmap <silent> gi <Plug>(coc-implementation)

  " Symbol renaming.
  " nmap <leader>rn <Plug>(coc-rename)

  " Formatting selected code.
  " xmap <leader>f  <Plug>(coc-format-selected)
  " nmap <leader>f  <Plug>(coc-format-selected)
  " Applying codeAction to the selected region.
  " Example: `<leader>aap` for current paragraph
  " xmap <leader>a  <Plug>(coc-codeaction-selected)
  " nmap <leader>a  <Plug>(coc-codeaction-selected)

  " Remap keys for applying codeAction to the current buffer.
  " nmap <leader>ac  <Plug>(coc-codeaction)
  " Apply AutoFix to problem on the current line.
  " nmap <leader>qf  <Plug>(coc-fix-current)

  " Lists the errors and warnings for the entire workspace
  " nnoremap <silent> <space>d :<C-u>CocList diagnostics<CR>

  " Symbols list - fuzzy-searchable of workspace symbosl
  " nnoremap <silent> <space>s :<C-u>CocList -I symbols<CR>

  " Perform codeaction on the word under the cursor
  " nmap <leader>do <Plug>(coc-codeaction)

  " Renaming a symbol
  " nmap <leader>rn <Plug>(coc-rename)
endif
