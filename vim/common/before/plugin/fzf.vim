let $FZF_DEFAULT_OPTS .= ' --inline-info'
let g:fzf_command_prefix = 'Fzf'

" Use Ripgrep or Ag if available
if executable('rg')
  " Like FzfAg but using Ripgrep
  command! -bang -nargs=* FzfRg
    \ call fzf#vim#grep(
    \   'rg --column --line-number --no-heading --color=always '.shellescape(<q-args>), 1,
    \   <bang>0 ? fzf#vim#with_preview('up:60%')
    \           : fzf#vim#with_preview('right:50%:hidden', '?'),
    \   <bang>0)
  nnoremap <Leader>fr :FzfRg<CR>
elseif executable('ag')
  " FzfAg but with option for preview using '?'
  command! -bang -nargs=* FzfAg
    \ call fzf#vim#ag(<q-args>,
    \                 <bang>0 ? fzf#vim#with_preview('up:60%')
    \                         : fzf#vim#with_preview('right:50%:hidden', '?'),
    \                 <bang>0)
  nnoremap <Leader>fa :FzfAg<CR>
endif

let g:fzf_layout = { 'down': '~25%' }

" let g:fzf_action = {
"   \ 'ctrl-t': 'tab split',
"   \ 'ctrl-x': 'split',
"   \ 'ctrl-v': 'vsplit' }

" [Files] Extra options for fzf
"   e.g. File preview using Highlight
"        (http://www.andre-simon.de/doku/highlight/en/highlight.html)
if has('unix')
  let g:fzf_files_options =
    \ '--preview "(highlight -O ansi {} || cat {}) 2> /dev/null | head -'.&lines.'"'
elseif has('win32')
  " NOTE: Fzf vim on Windows, do not show preview.
  " At least until I can figure out how to use PowerShell to show preview.
  " let g:fzf_files_options = '--no-preview'
  " command! -bang -nargs=? -complete=dir FzfFiles
  "   \ call fzf#vim#files(<q-args>, {}, <bang>0)
  let g:fzf_preview_window = ''
endif

" [Buffers] Jump to the existing window if possible
let g:fzf_buffers_jump = 1

" [[B]Commits] Customize the options used by 'git log':
let g:fzf_commits_log_options = '--graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr"'

" [Tags] Command to generate tags file
let g:fzf_tags_command = 'ctags -R'

" [Commands] --expect expression for directly executing the command
let g:fzf_commands_expect = 'alt-enter,ctrl-x'

" Replace the default dictionary completion with fzf-based fuzzy completion
" inoremap <expr> <c-x><c-k> fzf#complete('cat /usr/share/dict/words')

" Neovim Floating Windows / Vim Popup Windows
if has('nvim')
  "Let the input go up and the search list go down
  let $FZF_DEFAULT_OPTS .= ' --layout=reverse'

  "Open FZF and choose floating window
  let g:fzf_layout = { 'window': 'call OpenFloatingWin()' }

  function! OpenFloatingWin()
    let height = &lines - 3
    let width = float2nr(&columns - (&columns * 2 / 10))
    let col = float2nr((&columns - width) / 2)

    "Set the position, size, etc. of the floating window.
    "The size configuration here may not be so flexible, and there's room for further improvement.
    let opts = {
          \ 'relative': 'editor',
          \ 'row': height * 0.3,
          \ 'col': col + 30,
          \ 'width': width * 2 / 3,
          \ 'height': height / 2
          \ }

    let buf = nvim_create_buf(v:false, v:true)
    let win = nvim_open_win(buf, v:true, opts)

    "Set Floating Window Highlighting
    call setwinvar(win, '&winhl', 'Normal:Pmenu')

    setlocal
          \ buftype=nofile
          \ nobuflisted
          \ bufhidden=hide
          \ nonumber
          \ norelativenumber
          " \ signcolumn=no
  endfunction
elseif !(v:version < 802)
  "Let the input go up and the search list go down
  let $FZF_DEFAULT_OPTS .= ' --layout=reverse'

  "Open FZF and choose floating window
  let g:fzf_layout = { 'window': {
                     \ 'width': 0.5,
                     \ 'height': 0.6
                     \ } }
endif

