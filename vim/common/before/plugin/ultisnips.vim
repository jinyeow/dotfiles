let g:UltiSnipsExpandTrigger       = '<c-s>'
let g:UltiSnipsJumpForwardTrigger  = '<c-j>'
let g:UltiSnipsJumpBackwardTrigger = '<c-k>'
let g:UltiSnipsEditSplit           = "vertical"

" Custom snippet directories for UltiSnips to check in the &runtimepath
let g:UltiSnipsSnippetDirectories  = ["UltiSnips", "mysnippets"]

" Refresh snippets once you finish editing and saving a snippets file.
autocmd! BufWritePost *.snippet UltiSnips#RefreshSnippets()

