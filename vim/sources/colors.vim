" ------------------"
" => COLOR SETTINGS "
" ------------------"

" set t_co=256
let hour = strftime("%H")
if 7 <= hour && hour < 18 " i.e. daytime
    set background=light
else
    set background=dark
endif

if has('unix')
  " Allow color schemes to do bright colors without forcing bold.
  if &t_Co == 8 && $TERM !~# '^linux\|^Eterm'
    set t_Co=16
  endif

  if (has("termguicolors"))
    set termguicolors
    silent! colorscheme desert
    silent! colorscheme NeoSolarized
    " colorscheme palenight
  else
    " Set 256 colorscheme.
    " Maybe some base16 one.
    colorscheme desert
  endif
elseif has('win32')
  " highlight CursorLine ctermfg=black ctermbg=white
  if has('nvim') || has('termguicolors')
    set termguicolors
  elseif has('gui_running')
    set guifont=Fira_Code_Retina:h10:W450:cANSI:qDRAFT
  endif

  silent! colorscheme desert
  silent! colorscheme one
  silent! colorscheme gruvbox
  silent! colorscheme NeoSolarized
  silent! colorscheme palenight
  silent! colorscheme embark
endif

