" ------------------"
" => FOLDS SETTINGS "
" ------------------"

" NOTE: The below set of options allows for automatic opening and closing of
" folds as you move through them.
" To disable set 'nofoldenable' or set the foldlevel to a high number i.e. foldlevel=99.
" Moving between folds with 'zj' and 'zk'.

" set foldclose=all " Close folds if you leave them in any way
" set foldcolumn=0 " Show the foldcolumn
" set foldenable " Turn on folding
" set foldlevel=0 " Autofold everything by default
" set foldmethod=marker " Fold on the marker '{' x3
" set foldnestmax=1 " I only like to fold outer functions
" set foldopen=all " Open folds if you touch them in any way

" Use [of, ]of, =of to enable/disable/toggle the automatic closing/opening of folds.
fu! s:open_folds(action) abort
    if a:action ==# 'is_active'
        return exists('s:open_folds')
    elseif a:action ==# 'enable' && !exists('s:open_folds')
        let s:open_folds = {
        \                    'close'   : &foldclose,
        \                    'column'  : &foldcolumn,
        \                    'enable'  : &foldenable,
        \                    'level'   : &foldlevel,
        \                    'method'  : &foldmethod,
        \                    'nestmax' : &foldnestmax,
        \                    'open'    : &foldopen,
        \                  }
        set foldclose=all
        set foldcolumn=1
        set foldenable
        set foldlevel=0
        set foldmethod=marker
        set foldnestmax=1
        set foldopen=all
        echo '[auto open folds] ON'
    elseif a:action ==# 'disable' && exists('s:open_folds')
        for op in keys(s:open_folds)
            exe 'let &fold'.op.' = s:open_folds.'.op
        endfor
        unlet! s:open_folds
        echo '[auto open folds] OFF'
    endif
endfu

nnoremap <silent> [of :<c-u>call <sid>open_folds('enable')<cr>
nnoremap <silent> ]of :<c-u>call <sid>open_folds('disable')<cr>
nnoremap <silent> =of :<c-u>call <sid>open_folds(<sid>open_folds('is_active') ?
  \ 'disable' : 'enable')<cr>
