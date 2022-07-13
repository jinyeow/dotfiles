" vim:foldmethod=marker:foldlevel=0
" ------------------"
" => FUNCTIONS      "
" ------------------"

" :A
function! s:a() " {{{
  let name = expand('%:r')
  let ext = tolower(expand('%:e'))
  let sources = ['c', 'cc', 'cpp', 'cxx']
  let headers = ['h', 'hh', 'hpp', 'hxx']
  for pair in [[sources, headers], [headers, sources]]
    let [set1, set2] = pair
    if index(set1, ext) >= 0
      for h in set2
        let aname = name.'.'.h
        for a in [aname, toupper(aname)]
          if filereadable(a)
            execute 'e' a
            return
          end
        endfor
      endfor
    endif
  endfor
endfunction " }}}
" command! A call s:a()

" Delete trailing whitespace on save, taken from eddie blundell vimrc
" getpos() returns an array of [?, ROW, COL, ?]
" The 'if' checks that the 'z' mark is not set in the current row already.
" Otherwise errors may occur (this is due to conflicts with vim-signature).
func! DeleteTrailingWS() " {{{
  if getpos("'z")[1] != line(".")
    exe "normal mz"
  endif
    %s/\s\+$//ge
    exe "normal `z"
endfunc " }}}
nnoremap ,ws :call DeleteTrailingWS()<CR>:w<CR>

" Follow symlinks when opening a file
" NOTE: this happens with directory symlinks anyway (due to Vim's chdir/getcwd
" magic when getting filenames).
" Sources:
" - github.com/tpope/vim-fugitive/issues/147#issuecomment-7572351
" - reddit.com/r/vim/comments/yhsn6/is_it_possible_to_work_around_the_symlink_bug/c5w91qw
function! MyFollowSymlink(...) " {{{
  if exists('w:no_resolve_symlink') && w:no_resolve_symlink
    return
  endif
  let fname = a:0 ? a:1 : expand('%')
  if fname =~ '^\w\+:/'
    " do not mess with 'fugitive://' etc
    return
  endif
  let fname = simplify(fname)

  let resolvedfile = resolve(fname)
  if resolvedfile == fname
    return
  endif
  let resolvedfile = fnameescape(resolvedfile)
  echohl WarningMsg | echomsg 'Resolving symlink' fname '=>' resolvedfile | echohl None
  " exec 'noautocmd file ' . resolvedfile
  " XXX: problems with AutojumpLastPosition: line("'\"") is 1 always.
  exec 'file ' . resolvedfile
endfunction " }}}
" command! FollowSymlink call MyFollowSymlink()

" Platform idenfitication {{{
silent function! OSX()
    return has('macunix')
endfunction

silent function! LINUX()
    return has('unix') && !has('macunix') && !has('win32unix')
endfunction

silent function! WINDOWS()
    return  (has('win16') || has('win32') || has('win64'))
endfunction

silent function! UNIXLIKE()
    return !WINDOWS()
endfunction

silent function! FREEBSD()
  let s:uname = system("uname -s")
  return (match(s:uname, 'FreeBSD') >= 0)
endfunction
" }}}

" GitBranch for StatusLine
function! GitBranch() " {{{
  try
    if has('unix')
      return system("git rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '\n'")
    elseif has('win32')
      return '' "system("git rev-parse --abrev-ref HEAD")
    endif
  catch
    return ''
  endtry
endfunction

function! StatuslineGit()
  let l:branchname = GitBranch()
  return strlen(l:branchname) > 0 ? ' '.l:branchname.' ' : ''
  " return strlen(l:branchname) > 0 ? '  '.l:branchname.' ' : ''
endfunction
" }}}

" Returns whether inside a Rails Project
" NOTE: this may have been causing my startup problems
function! InRailsProject() " {{{
  if !has('nvim')
    return 0
  endif
  return strlen(system("test -f \"./config/application.rb\" && ag \"require 'rails/all'\"")) > 0 ? 1 : 0
endfunction
" }}}

" [Kwbd] A Better :bd - taken from:
"   http://vim.wikia.com/wiki/Deleting_a_buffer_without_closing_the_window
" delete the buffer; keep windows; create a scratch buffer if no buffers left
function! s:Kwbd(kwbdStage) " {{{
  if(a:kwbdStage == 1)
    if(!buflisted(winbufnr(0)))
      bd!
      return
    endif
    let s:kwbdBufNum = bufnr("%")
    let s:kwbdWinNum = winnr()
    windo call s:Kwbd(2)
    execute s:kwbdWinNum . 'wincmd w'
    let s:buflistedLeft = 0
    let s:bufFinalJump = 0
    let l:nBufs = bufnr("$")
    let l:i = 1
    while(l:i <= l:nBufs)
      if(l:i != s:kwbdBufNum)
        if(buflisted(l:i))
          let s:buflistedLeft = s:buflistedLeft + 1
        else
          if(bufexists(l:i) && !strlen(bufname(l:i)) && !s:bufFinalJump)
            let s:bufFinalJump = l:i
          endif
        endif
      endif
      let l:i = l:i + 1
    endwhile
    if(!s:buflistedLeft)
      if(s:bufFinalJump)
        windo if(buflisted(winbufnr(0))) | execute "b! " . s:bufFinalJump | endif
      else
        enew
        let l:newBuf = bufnr("%")
        windo if(buflisted(winbufnr(0))) | execute "b! " . l:newBuf | endif
      endif
      execute s:kwbdWinNum . 'wincmd w'
    endif
    if(buflisted(s:kwbdBufNum) || s:kwbdBufNum == bufnr("%"))
      execute "bd! " . s:kwbdBufNum
    endif
    if(!s:buflistedLeft)
      set buflisted
      set bufhidden=delete
      set buftype=
      setlocal noswapfile
    endif
  else
    if(bufnr("%") == s:kwbdBufNum)
      let prevbufvar = bufnr("#")
      if(prevbufvar > 0 && buflisted(prevbufvar) && prevbufvar != s:kwbdBufNum)
        b #
      else
        bn
      endif
    endif
  endif
endfunction " }}}
command! Bdelete call s:Kwbd(1)
noremap <Leader>d :Bdelete<CR>

" https://gist.github.com/romainl/047aca21e338df7ccf771f96858edb86
" Provides a prompt for each of the commands listed below.
" Make list-like commands more intuitive.
" function! CCR() " {{{
"     let cmdline = getcmdline()
"     if cmdline =~ '\v\C^(ls|files|buffers)'
"         " like :ls but prompts for a buffer command
"         return "\<CR>:b"
"     elseif cmdline =~ '\v\C/(#|nu|num|numb|numbe|number)$'
"         " like :g//# but prompts for a command
"         return "\<CR>:"
"     elseif cmdline =~ '\v\C^(dli|il)'
"         " like :dlist or :ilist but prompts for a count for :djump or :ijump
"         return "\<CR>:" . cmdline[0] . "j  " . split(cmdline, " ")[1] . "\<S-Left>\<Left>"
"     elseif cmdline =~ '\v\C^(cli|lli)'
"         " like :clist or :llist but prompts for an error/location number
"         return "\<CR>:sil " . repeat(cmdline[0], 2) . "\<Space>"
"     elseif cmdline =~ '\C^old'
"         " like :oldfiles but prompts for an old file to edit
"         set nomore
"         return "\<CR>:sil se more|e #<"
"     elseif cmdline =~ '\C^changes'
"         " like :changes but prompts for a change to jump to
"         set nomore
"         return "\<CR>:sil se more|norm! g;\<S-Left>"
"     elseif cmdline =~ '\C^ju'
"         " like :jumps but prompts for a position to jump to
"         set nomore
"         return "\<CR>:sil se more|norm! \<C-o>\<S-Left>"
"     elseif cmdline =~ '\C^marks'
"         " like :marks but prompts for a mark to jump to
"         return "\<CR>:norm! `"
"     elseif cmdline =~ '\C^undol'
"         " like :undolist but prompts for a change to undo
"         return "\<CR>:u "
"     else
"         return "\<CR>"
"     endif
" endfunction
" cnoremap <expr> <CR> CCR()
" }}}
" https://www.reddit.com/r/vim/comments/7iy03o/you_aint_gonna_need_it_your_replacement_for/dr2qo4k/
" The below is a new version of the above CCR() function, taken from the above Reddit post.
cnoremap <expr> <CR> <SID>CCR() " {{{
function! s:CCR()
    command! -bar Z silent set more|delcommand Z
    if getcmdtype() == ":"
        let cmdline = getcmdline()
            if cmdline =~ '\v\C^(dli|il)' | return "\<CR>:" . cmdline[0] . "jump   " . split(cmdline, " ")[1] . "\<S-Left>\<Left>\<Left>"
        elseif cmdline =~ '\v\C^(cli|lli)' | return "\<CR>:silent " . repeat(cmdline[0], 2) . "\<Space>"
        elseif cmdline =~ '\C^changes' | set nomore | return "\<CR>:Z|norm! g;\<S-Left>"
        elseif cmdline =~ '\C^ju' | set nomore | return "\<CR>:Z|norm! \<C-o>\<S-Left>"
        elseif cmdline =~ '\v\C(#|nu|num|numb|numbe|number)$' | return "\<CR>:"
        elseif cmdline =~ '\C^ol' | set nomore | return "\<CR>:Z|e #<"
        elseif cmdline =~ '\v\C^(ls|files|buffers)' | return "\<CR>:b"
        elseif cmdline =~ '\C^marks' | return "\<CR>:norm! `"
        elseif cmdline =~ '\C^undol' | return "\<CR>:u "
        else | return "\<CR>" | endif
    else | return "\<CR>" | endif
endfunction
" }}}

" Sets the arglist (:args) to contain each file referenced in the quicklist.
" This is useful for when using a Vim that doesn't include :cdo/:ldo.
function! QuickfixFilenames() " {{{
  " Building a hash ensures we get each buffer only once
  let buffer_numbers = {}
  for quickfix_item in getqflist()
    let buffer_numbers[quickfix_item['bufnr']] = bufname(quickfix_item['bufnr'])
  endfor
  return join(map(values(buffer_numbers), 'fnameescape(v:val)'))
endfunction
command! -nargs=0 -bar Qargs execute 'args' QuickfixFilenames()
" }}}

" Search for current word and replace with given text for files in arglist.
" NOTE: Example of a 'replace' type function across multiple files.
"       Study it for my own Search'n'Replace type function.
" function! Replace(bang, replace) " {{{
"   let flag = 'ge'
"   if !a:bang
"     let flag .= 'c'
"   endif
"   let search = '\<' . escape(expand('<cword>'), '/\.*$^~[') . '\>'
"   let replace = escape(a:replace, '/\&~')
"   execute 'argdo %s/' . search . '/' . replace . '/' . flag
" endfunction
" command! -nargs=1 -bang Replace :call Replace(<bang>0, <q-args>)
" nnoremap <Leader>r :call Replace(0, input('Replace '.expand('<cword>').' with: '))<CR>
" }}}

" Perform replace on all results in the quickfix from the last search.
function! QFReplace(bang, replace) " {{{
  let l:flag = 'ge'
  if !a:bang
    let l:flag .= 'c'
  endif
  let replace = escape(a:replace, '/\&~')
  execute 'cdo %s//' . replace . '/g' . l:flag
endfunction " }}}
command! -bang -nargs=1 CReplace call QFReplace(<bang>0,<f-args>)
nnoremap ,gr :call QFReplace(1, input("Replace '".expand('<C-R>/')."' with: "))<CR>

function! GetVisualSelection() " {{{
    " Why is this not a built-in Vim script function?!
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return ''
    endif
    let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][column_start - 1:]
    return join(lines, "\n")
endfunction " }}}

" Opens a Scratch Buffer that can be given various options (e.g. syntax highlighting)
" e.g. :Sedit ft=ruby opens a scratch buffer with ruby syntax
" The buffer is not listed in :ls and after :q it will be wiped completely.
function! functions#ScratchEdit(cmd, options) " {{{
	exe a:cmd tempname()
	setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
	if !empty(a:options) | exe 'setlocal' a:options | endif
endfunction

command! -bar -nargs=* Sedit call functions#ScratchEdit('edit', <q-args>)
command! -bar -nargs=* Ssplit call functions#ScratchEdit('split', <q-args>)
command! -bar -nargs=* Svsplit call functions#ScratchEdit('vsplit', <q-args>)
command! -bar -nargs=* Stabedit call functions#ScratchEdit('tabe', <q-args>)
" }}}

" Search Suggestions AutoComplete
function! s:search_mode_start()
    cnoremap <tab> <c-f>a<c-n>
    let s:old_complete_opt = &completeopt
    set completeopt-=noinsert
endfunction

function! s:search_mode_stop()
    cunmap <tab>
    let &completeopt = s:old_complete_opt
endfunction

" Not available on Neovim version <= 0.2.2
" augroup search_mode
"   autocmd!
"   autocmd CmdlineEnter [/\?] call <SID>search_mode_start()
"   autocmd CmdlineLeave [/\?] call <SID>search_mode_stop()
" augroup END

" Window splitting / movement
" function! WinMove(key)
"     let t:curwin = winnr()
"     exec "wincmd ".a:key
"     if (t:curwin == winnr())
"         if (match(a:key,'[jk]'))
"             wincmd v
"         else
"             wincmd s
"         endif
"         exec "wincmd ".a:key
"     endif
" endfunction
" " NOTE: <C-h> mapping does not work (at least not on Neovim).
" noremap <silent> <C-h> :call WinMove('h')<CR>
" noremap <silent> <C-j> :call WinMove('j')<CR>
" noremap <silent> <C-k> :call WinMove('k')<CR>
" noremap <silent> <C-l> :call WinMove('l')<CR>
