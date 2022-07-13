"=================================================================
"   StatusLine:                                                  =
"=================================================================

" set statusline+=%(%{&paste?'\ p\ ':''}%)
" set statusline+=%(\ \ %{fugitive#head()}%)
" set statusline+=%([%n]%<\ %p%%\ ☰\ \ %l/%L\ \ :%c\ %)

" Dictionary: take mode() input -> longer notation of current mode
" mode() is defined by Vim
let g:currentmode={
      \'n' : 'Normal ',
      \'no' : 'N·Operator Pending ',
      \'v' : 'Visual ',
      \'V' : 'V·Line ',
      \'^V' : 'V·Block ',
      \'s' : 'Select ',
      \'S': 'S·Line ',
      \'^S' : 'S·Block ',
      \'i' : 'Insert ',
      \'R' : 'Replace ',
      \'Rv' : 'V·Replace ',
      \'c' : 'Command ',
      \'cv' : 'Vim Ex ',
      \'ce' : 'Ex ',
      \'r' : 'Prompt ',
      \'rm' : 'More ',
      \'r?' : 'Confirm ',
      \'!' : 'Shell ',
      \'t' : 'Terminal '
      \}


" Function: return current mode
" abort -> function will abort soon as error detected
function! ModeCurrent() abort " {{{
    let l:modecurrent = mode()
    " use get() -> fails safely, since ^V doesn't seem to register
    " 3rd arg is used when return of mode() == 0, which is case with ^V
    " thus, ^V fails -> returns 0 -> replaced with 'V Block'
    let l:modelist = toupper(get(g:currentmode, l:modecurrent, 'V·Block '))
    let l:current_status_mode = l:modelist
    return l:current_status_mode
endfunction " }}}

function! FileSize() abort " {{{
    let l:bytes = getfsize(expand('%p'))
    if (l:bytes >= 1024)
        let l:kbytes = l:bytes / 1025
    endif
    if (exists('kbytes') && l:kbytes >= 1000)
        let l:mbytes = l:kbytes / 1000
    endif
 
    if l:bytes <= 0
        return '0'
    endif
  
    if (exists('mbytes'))
        return l:mbytes . 'MB '
    elseif (exists('kbytes'))
        return l:kbytes . 'KB '
    else
        return l:bytes . 'B '
    endif
endfunction " }}}

function! ReadOnly() abort " {{{
  if &readonly || !&modifiable
    return ''
  else
    return ''
endfunction " }}}

" Statusline
set statusline=
set statusline+=\                  " Blank space
set statusline+=\ %{ModeCurrent()} " Show mode (normal/insert/etc.)
set statusline+=\                  " Blank space
set statusline+=%#PmenuSel#

set statusline+=\                  " Blank space
set statusline+=%t                 " Path to the file in the buffer
set statusline+=%h%w%m             " Modified flag
set statusline+=\                  " Blank space
set statusline+=%y                 " Type of file in the buffer
set statusline+=\                  " Blank space

set statusline+=%#LineNr#
set statusline+=%(%{&paste?'\ --PASTE--\ ':''}%)

" set statusline+=%(\ Q:%{substitute(len(getqflist()),'^0','','')}%)

set statusline+=%{StatuslineGit()} " Current branch"

set statusline+=%=                 " Align to the right from now on
set statusline+=\ \[%{&fileencoding?&fileencoding:&encoding},
set statusline+=\ %{&fileformat}\]

set statusline+=\                  " Blank space
set statusline+=%#PmenuSel#
set statusline+=\                  " Blank space

set statusline+=%l                 " Current line
set statusline+=/                  " Slash
set statusline+=%L                 " Total lines
set statusline+=:%v                " Virtual column number
set statusline+=\                  " Blank space
set statusline+=%p%%               " Percentage through the file
set statusline+=\ 

" " Highlight status bar when in insert mode
" if version >= 700
"   augroup StsLn
"     au InsertEnter * hi StatusLine ctermfg=235 ctermbg=2
"     au InsertLeave * hi StatusLine ctermfg=white ctermbg=blue
"   augroup end
" endif

