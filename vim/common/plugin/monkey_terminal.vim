if exists("g:loaded_monkey_terminal") || &compatible || !has('nvim')
  finish
endif
let g:loaded_monkey_terminal = 1

let s:save_cpo = &cpo
set cpo&vim


" With this function you can reuse the same terminal in neovim.
" You can toggle the terminal and also send a command to the same terminal.
" Taken from: https://gist.github.com/ram535/b1b7af6cd7769ec0481eb2eed549ea23
"   22/1/18
" NOTE: currently only works in Neovim.
"   There is no termopen in Vim apparently.

let s:monkey_terminal_window = -1
let s:monkey_terminal_buffer = -1
let s:monkey_terminal_job_id = -1

function! MonkeyTerminalOpen()
  " Check if buffer exists, if not create a window and a buffer
  if !bufexists(s:monkey_terminal_buffer)
    " Creates a window call monkey_terminal
    new monkey_terminal
    " Moves to the window below the current one
    wincmd L
    let s:monkey_terminal_job_id = termopen($SHELL, { 'detach': 1 })

     " Change the name of the buffer to "Monkey Terminal"
     silent file Monkey\ Terminal
     " Gets the id of the terminal window
     let s:monkey_terminal_window = win_getid()
     let s:monkey_terminal_buffer = bufnr('%')

    " The buffer of the terminal won't appear in the list of the buffers
    " when calling :buffers command
    set nobuflisted
  else
    if !win_gotoid(s:monkey_terminal_window)
    sp
    " Moves to the window below the current one
    wincmd L   
    buffer Monkey\ Terminal
     " Gets the id of the terminal window
     let s:monkey_terminal_window = win_getid()
    endif
  endif
endfunction

function! MonkeyTerminalToggle()
  if win_gotoid(s:monkey_terminal_window)
    call MonkeyTerminalClose()
  else
    call MonkeyTerminalOpen()
  endif
endfunction

function! MonkeyTerminalClose()
  if win_gotoid(s:monkey_terminal_window)
    " close the current window
    hide
  endif
endfunction

function! MonkeyTerminalExec(cmd)
  if !win_gotoid(s:monkey_terminal_window)
    call MonkeyTerminalOpen()
  endif

  " clear current input
  call jobsend(s:monkey_terminal_job_id, "clear\n")

  " run cmd
  call jobsend(s:monkey_terminal_job_id, a:cmd . "\n")
  normal! G
  wincmd p
endfunction

" Default mappings
if ! exists("g:monkey_terminal_default_mappings")
  nnoremap <silent> \mt :call MonkeyTerminalToggle()<cr>
  tnoremap <silent> \mt <C-\><C-n>:call MonkeyTerminalToggle()<cr>
endif

let &cpo = s:save_cpo

" NOTE: A simple alternative to monkey_terminal
"   Check it out and maybe use some of it to make this plugin work
"   for both Vim and Neovim
" " Toggle 'default' terminal
" nnoremap <M-`> :call ChooseTerm("term-slider", 1)<CR>
" " Start terminal in current pane
" nnoremap <M-CR> :call ChooseTerm("term-pane", 0)<CR>
 
" function! ChooseTerm(termname, slider)
"     let pane = bufwinnr(a:termname)
"     let buf = bufexists(a:termname)
"     if pane > 0
"         " pane is visible
"         if a:slider > 0
"             :exe pane . "wincmd c"
"         else
"             :exe "e #"
"         endif
"     elseif buf > 0
"         " buffer is not in pane
"         if a:slider
"             :exe "topleft split"
"         endif
"         :exe "buffer " . a:termname
"     else
"         " buffer is not loaded, create
"         if a:slider
"             :exe "topleft split"
"         endif
"         :terminal
"         :exe "f " a:termname
"     endif
" endfunction
