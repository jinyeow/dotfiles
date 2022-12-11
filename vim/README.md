## VIM

This is the directory that contains all config related to my Neovim/Vim setup.

The following is a list of the contents of this directory:

- `common/` directory holds the `autoload/` and `plugged/` directories which are
  common for both Neovim and Vim.

- `config.vim` is the aggregrate file that is symlinked to vimrc/init.vim.

- `custom/` directory holds any custom files. e.g. colorschemes

- `projections/` contains templates for Projectionist. My zsh function
  `generate projection FILETYPE` uses these templates to create the necessary
  .projections file in my projects.

- `sources/` directory contains all the defined config files. These include but are
  not limited to functions, plugins, and various configuration settings.

" => CHEATSHEET OF MAPPINGS: {{{
" <Leader>n, p, d -> buffer next/previous/delete
" <Leader>fml -> vim-follow-my-leader
" <Leader>tc -> Colorizer
" <Space><Space> -> Search and Replace word under cursor FORWARD ONLY
" <Space>% -> Search and Replace word under cursor ALL
" ,ws -> :call DeleteTrailingWS()<CR>:w<CR>
" :SC -> Open a scratch buffer
" :IX -> Share snippet thru ix.io
" :Ags
" :Grep
"
" vim-signature --------------------------------------------------------------
" m, -> place the next available mark
" m. -> If no mark on line, place the next available mark. Else delete mark.
" m- -> Delete all marks from the current line
" m<Space> -> Delete all marks from the current buffer.
" ]`,[` -> Jump to next/prev mark
" ]',[' -> Jump to start of next/prev line containing a mark
" `],`[,'],'[ -> Same as above but jump alphabetically
" m/ -> Open location list and display marks from current buffer.
"
" buffer navigation ----------------------------------------------------------
" gb -> :ls<CR>:buffer<Space>
" gB -> :ls<CR>:sbuffer<Space>
" ,b -> :buffer _
" ,B -> :sbuffer _
"
" file navigation ------------------------------------------------------------
" ,f/,F -> :find _
" ,s/,S -> :sfind _
" ,v/,V -> :vert sfind _
" ,t/,T -> :tabfind _
"
" symbol navigation ----------------------------------------------------------
" ,j -> :tjump /
" ,p -> :ptjump /
" ,i -> :ilist /
" [I/]I
" ,d -> :dlist /
" [D/]D
"
" fzf.vim --------------------------------------------------------------------
" <Leader>fr -> FzfRg
" <Leader>fa -> FzfAg
" <Leader>ff -> FzfFiles
" <Leader>fF -> FzfFiles ~
" <Leader>fb -> FzfBuffers
" <Leader>fw -> FzfWindows
" <Leader>fg -> FzfGitFiles
" <Leader>fc -> FzfCommits
" <Leader>ft -> FzfTags
" <Leader>fT -> FzfBTags
" <Leader>fl -> FzfLines
" <Leader>fL -> FzfBLines
" <Leader>fM -> FzfMarks
" <Leader>fh -> FzfHistory
" :Fzf{Controllers,Models,Views,Migrations,Specs,
"
" vim-grepper ----------------------------------------------------------------
" ,gg -> :Grepper{Rg,Ag,Grep}<Space>
" ,ga -> like ,gg but for the word under the cursor
" gs<operator> -> vim-grepper operator e.g. gsw, gsi", etc.
"
" vim-qf ---------------------------------------------------------------------
" <Leader>qf -> <Plug>qf_qf_toggle
" <Leader>qq -> <Plug>qf_qf_stay_toggle
"
" vim-vimwiki ----------------------------------------------------------------
" <Leader>ww -> <Plug>VimwikiIndex
" <Leader>wt -> <Plug>VimwikiTabIndex
" <Leader>ws -> <Plug>VimwikiUISelect
" <Leader>wi -> <Plug>VimwikiDiaryIndex
" <Leader>w<Space>i -> <Plug>VimwikiDiaryGenerateLinks
" <Leader>w<Space>w -> <Plug>VimwikiMakeDiaryNote
" <Leader>w<Space>t -> <Plug>VimwikiTabMakeDiaryNote
" <Leader>w<Space>y -> <Plug>VimwikiMakeYesterdayDiaryNote
"

" => Other 'MODES':
" c.vim -> \[additional characters] (see c-support-mappings.txt)
" vimtex -> \l[additional characters]
" -> \lv
" -> \li
" -> \lg
" -> \lc
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
