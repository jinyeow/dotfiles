if executable('rg')
  set grepprg=rg\ --column\ --no-heading\ --smart-case\ --follow
  set grepformat=%f:%l:%c:%m,%f:%l:%m
  " set grepformat^=%f:%l:%c:%m
elseif executable('ag')
  let &grepprg = 'ag --nogroup --nocolor --column'
  let g:ag_working_path_mode="r"
else
  if has('unix')
    let &grepprg = 'grep -rn $* *'
  elseif has('win32')
    let &grepprg = 'findstr /n'
  endif
endif

command! -nargs=1 -bar Grep execute 'silent! grep! <q-args>' | redraw! | copen
cnoreabbrev Find Grep

