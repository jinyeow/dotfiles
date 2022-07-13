"=================================================================
"   TabLine:                                                     =
"=================================================================

function! MyBufLine() abort " {{{1
    let l:bl = '%#TablineFill#' " bg of tabline
    let l:bufs = s:Buffers()    " list of buffers
    let l:bufs_n = len(l:bufs)  " number of buffers in the list
    for l:b in l:bufs           " l:b is the 'current' buffer
        " do not show Terminal buffers in the buffer line
        if getbufvar(l:b, '&buftype') ==# 'terminal'
          continue
        endif

        " NOTE: The case where we have 1 buffer is checked in TLInit().

        " If more than 8, show only '[B] #numberOfBuffers'
        if l:bufs_n >=# 8
            let l:bl .= '%#TabLine# [B] ' . l:bufs_n . ' %#TabLineFill# '
            break
        endif

        let l:mod = (getbufvar(l:b, '&modified') ==# 1 ? ' +' : '')
        let l:name = (!empty(bufname(l:b)) ?
                    \   pathshorten(fnamemodify(bufname(l:b), ':.')) . l:mod :
                    \   '[No Name]'
                    \ )

        let l:bl .= (l:b ==# bufnr('%') ? '%#PmenuSel# ' . l:name :
                    \ '%#Folded# ' . l:name) . ' %#LineNr# '
    endfor

    let l:get_cwd = fnamemodify(getcwd(), ':p:~')
    if l:get_cwd !=# '~/'
        let l:cwd = len(l:get_cwd) >=# 15 ? pathshorten(fnamemodify(l:get_cwd, ':p:~:h')) : l:get_cwd
        let l:bl .= '%=%#IncSearch# ' . l:cwd . ' '
    else
        " let l:bl .= '%=%#IncSearch# ' . '$HOME' . ' '
        let l:bl .= '%=%#IncSearch# ' . pathshorten(getcwd()) . ' '
    endif

    return l:bl
endfunction
" 1}}}

function! MyTabLine() abort " {{{1
    " :h setting-tabline

    let l:tl = '%#TabLineSel# [T] %#TabLineFill#'
    for i in range(tabpagenr('$'))
        let l:i = i + 1
        let l:tl .= (l:i ==# tabpagenr()) ?
                    \ ' %#PmenuSel#' : ' %#Folded#'
        " Set the tab page number (for mouse clicks)
        let l:tl .= '%' . l:i . 'T '
        Get working directory (Use tabpagecd if present, otherwise use
        getcwd()).
        if !empty(gettabvar(l:i, 'cwd'))
            let l:tl .= tabpagenr('$') >=# 5 ?
                        \ fnamemodify(gettabvar(l:i, 'cwd'), ':t') :
                        \ pathshorten(fnamemodify(gettabvar(l:i, 'cwd'), ':~'))
        else
            let l:tl .= tabpagenr('$') >=# 5 ?
                        \ fnamemodify(getcwd(), ':t') :
                        \ pathshorten(fnamemodify(getcwd(), ':~'))
        endif
        let l:tl .= '%' . l:i . 'X ⨉'
        " Fill with TabLineFill and reset tab page nr
        let l:tl .= ' %#TabLineFill#%T'
    endfor

    let l:get_cwd = fnamemodify(getcwd(), ':p:~')
    if l:get_cwd !=# '~/'
        let l:cwd = len(l:get_cwd) >=# 15 ? pathshorten(fnamemodify(l:get_cwd, ':p:~:h')) : l:get_cwd
        let l:tl .= '%=%#IncSearch# ' . l:cwd . ' '
    else
        " let l:bl .= '%=%#IncSearch# ' . '$HOME' . ' '
        let l:tl .= '%=%#IncSearch# ' . pathshorten(getcwd()) . ' '
    endif

    return l:tl
endfunction
" 1}}}

function! TLInit() abort " {{{1
    let l:bufs = s:Buffers()
    " NOTE: I commented this out cos I want to ALWAYS show tabline
    " if len(s:Buffers()) ==# 1 && getcwd() ==# $HOME
    "     set showtabline=0
    "     return
    " endif
    set tabline=
    set showtabline=2
    if tabpagenr('$') ==# 1
        let l:bufs = l:bufs
        let &showtabline = len(l:bufs) ># 1 ? 2 : &showtabline
        set tabline=%!MyBufLine()
    else
        set showtabline=2
        set tabline=%!MyTabLine()
    endif
endfunction
" 1}}}

" ========== HELPERS ========================================

function! s:Buffers() abort " {{{1
    return filter(range(1, bufnr('$')), 'buflisted(v:val)')
endfunction
" 1}}}

" ========== INITIALIZE ========================================

" {{{1
hi! link TablineSel StatusLine
augroup TabBufLine
    autocmd!
    autocmd BufAdd,BufDelete,BufWinEnter,TabNew,TabClosed,VimEnter *
                \ call TLInit()
augroup END
call TLInit()
" 1}}}

" ========== MAPPINGS ==========================================

" Replace default <F5> {{{1
" nnoremap <silent> <F5> :tabonly\|call TLInit()<CR>
" 1}}}


" vim:ft=vim:fdm=marker:fmr={{{,}}}:
