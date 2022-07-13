" vim:foldmethod=marker:foldlevel=0

" CREATED: 18/11/17 00:46
" UPDATED: 01/07/20 

" => CHEATSHEET OF MAPPINGS: {{{
" <Leader>n, p, d         -> buffer next/previous/delete
" <Leader>fml             -> vim-follow-my-leader
" <Leader>tc              -> Colorizer
" <Space><Space>          -> Search and Replace word under cursor FORWARD ONLY
" <Space>%                -> Search and Replace word under cursor ALL
" ,ws                     -> :call DeleteTrailingWS()<CR>:w<CR>
" :SC                     -> Open a scratch buffer
" :IX                     -> Share snippet thru ix.io
" :Ags
" :Grep
"
" vim-signature --------------------------------------------------------------
" m,          -> place the next available mark
" m.          -> If no mark on line, place the next available mark. Else delete mark.
" m-          -> Delete all marks from the current line
" m<Space>    -> Delete all marks from the current buffer.
" ]`,[`       -> Jump to next/prev mark
" ]',['       -> Jump to start of next/prev line containing a mark
" `],`[,'],'[ -> Same as above but jump alphabetically
" m/          -> Open location list and display marks from current buffer.
"
" buffer navigation ----------------------------------------------------------
" gb                      -> :ls<CR>:buffer<Space>
" gB                      -> :ls<CR>:sbuffer<Space>
" ,b                      -> :buffer *
" ,B                      -> :sbuffer *
"
" file navigation ------------------------------------------------------------
" ,f/,F                   -> :find *
" ,s/,S                   -> :sfind *
" ,v/,V                   -> :vert sfind *
" ,t/,T                   -> :tabfind *
"
" symbol navigation ----------------------------------------------------------
" ,j                      -> :tjump /
" ,p                      -> :ptjump /
" ,i                      -> :ilist /
" [I/]I
" ,d                       -> :dlist /
" [D/]D
"
" fzf.vim --------------------------------------------------------------------
" <Leader>fr              -> FzfRg
" <Leader>fa              -> FzfAg
" <Leader>ff              -> FzfFiles
" <Leader>fF              -> FzfFiles ~
" <Leader>fb              -> FzfBuffers
" <Leader>fw              -> FzfWindows
" <Leader>fg              -> FzfGitFiles
" <Leader>fc              -> FzfCommits
" <Leader>ft              -> FzfTags
" <Leader>fT              -> FzfBTags
" <Leader>fl              -> FzfLines
" <Leader>fL              -> FzfBLines
" <Leader>fM              -> FzfMarks
" <Leader>fh              -> FzfHistory
"   :Fzf{Controllers,Models,Views,Migrations,Specs,
"
" vim-grepper ----------------------------------------------------------------
" ,gg                     -> :Grepper{Rg,Ag,Grep}<Space>
" ,ga                     -> like ,gg but for the word under the cursor
" gs<operator>            -> vim-grepper operator e.g. gsw, gsi", etc.
"
" vim-qf ---------------------------------------------------------------------
" <Leader>qf              -> <Plug>qf_qf_toggle
" <Leader>qq              -> <Plug>qf_qf_stay_toggle
"
" vim-vimwiki ----------------------------------------------------------------
" <Leader>ww              -> <Plug>VimwikiIndex
" <Leader>wt              -> <Plug>VimwikiTabIndex
" <Leader>ws              -> <Plug>VimwikiUISelect
" <Leader>wi              -> <Plug>VimwikiDiaryIndex
" <Leader>w<Space>i       -> <Plug>VimwikiDiaryGenerateLinks
" <Leader>w<Space>w       -> <Plug>VimwikiMakeDiaryNote
" <Leader>w<Space>t       -> <Plug>VimwikiTabMakeDiaryNote
" <Leader>w<Space>y       -> <Plug>VimwikiMakeYesterdayDiaryNote
"

" => Other 'MODES':
" c.vim     -> \[additional characters] (see c-support-mappings.txt)
" vimtex    -> \l[additional characters]
"           -> \lv
"           -> \li
"           -> \lg
"           -> \lc
"
" => 'emmet' KEYBINDINGS:
" <C-y>, -> activate HTML snippet

" }}}
" => fzf-vim-commands {{{
"  -----------------+----------------------------------------------------------
"  Command          | List                                                                ~
"  -----------------+----------------------------------------------------------
" `Files [PATH]`    | Files (similar to  `:FZF` )
" `GitFiles`        | Git files
" `Buffers`         | Open buffers
" `Colors`          | Color schemes
" `Ag [PATTERN]`    | {ag}{5} search result (ALT-A to select all, ALT-D to deselect all)
" `Lines`           | Lines in loaded buffers
" `BLines`          | Lines in the current buffer
" `Tags`            | Tags in the project ( `ctags -R` )
" `BTags`           | Tags in the current buffer
" `Marks`           | Marks
" `Windows`         | Windows
" `Locate PATTERN`  |  `locate`  command output
" `History`         |  `v:oldfiles`  and open buffers
" `History:`        | Command history
" `History/`        | Search history
" `Snippets`        | Snippets ({UltiSnips}{6})
" `Commits`         | Git commits (requires {fugitive.vim}{7})
" `BCommits`        | Git commits for the current buffer
" `Commands`        | Commands
" `Maps`            | Normal mode mappings
" `Helptags`        | Help tags [1]
"-----------------+------------------------------------------------------------
"
" }}}

" NOTE: g-/g+ more thorough undo/redo
" NOTE: \mt triggers monkey terminal toggle

" Utility Functions {{{
" Function to source only if file exists
function! SourceIfExists(file)
  if filereadable(expand(a:file))
    exe 'source' a:file
  endif
endfunction

" Function to source all .vim files in directory
function! SourceDirectory(file)
  for s:fpath in split(globpath(a:file, '*.vim'), '\n')
    exe 'source' s:fpath
  endfor
endfunction
" }}}

" Use before config if available
call SourceIfExists("~/.vimrc.before")

if has('unix')
  let g:vim_include_plugins = 1
  let vim_dotdir = $HOME . '/dotfiles/vim'
elseif has('win32')
  let g:vim_include_plugins = 1
  let vim_dotdir = $HOME . '/OneDrive/dotfiles/vim'
endif

exe 'set rtp^=' . expand(vim_dotdir . '/common')
exe 'set rtp+=' . expand(vim_dotdir . '/common/after')

" For any plugin configuration that needs to be set before the actual loading of the plugin
for f in split(glob(vim_dotdir . '/common/before/plugin/*.vim'), '\n')
  " echom "Sourcing: " . f
  exe 'source' f
endfor

" Basics {{{
execute 'source ' . vim_dotdir . '/sources/basic.vim'
execute 'source ' . vim_dotdir . '/sources/folds.vim'
execute 'source ' . vim_dotdir . '/sources/mappings.vim'
execute 'source ' . vim_dotdir . '/sources/commands.vim'
" }}}
" Extended - Functions + Autocmds {{{
execute 'source ' . vim_dotdir . '/sources/functions.vim'
execute 'source ' . vim_dotdir . '/sources/autocmds.vim'
" }}}
" Plugins {{{
if g:vim_include_plugins == 1
  execute 'source ' . vim_dotdir . '/sources/plugins.vim'
endif
" }}}
" Colors/Theming {{{
execute 'source ' . vim_dotdir . '/sources/colors.vim'
execute 'source ' . vim_dotdir . '/sources/statusline.vim'
execute 'source ' . vim_dotdir . '/sources/tabline.vim'
" }}}

" match ErrorMsg '\%>120v.\+'
" match ErrorMsg '\s\+$'

" Include user's local vim config
" if filereadable(expand("~/.vimrc.local")) | source ~/.vimrc.local | endif
call SourceIfExists("~/.vimrc.local")

