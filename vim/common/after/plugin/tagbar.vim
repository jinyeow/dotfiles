if &rtp =~ 'tagbar'
  " <F10> | Tagbar
  if v:version >= 703
    inoremap <F10> <ESC>:TagbarToggle<CR>
    nnoremap <F10> :TagbarToggle<CR>
    let g:tagbar_sort      = 1
    let g:tagbar_autofocus = 1

    let g:tagbar_type_crystal = {
        \'ctagstype': 'crystal',
        \'ctagsbin': 'crystalctags',
        \'kinds': [
            \'c:classes',
            \'m:modules',
            \'d:defs',
            \'x:macros',
            \'l:libs',
            \'s:sruct or unions',
            \'f:fun'
        \],
        \'sro': '.',
        \'kind2scope': {
            \'c': 'namespace',
            \'m': 'namespace',
            \'l': 'namespace',
            \'s': 'namespace'
        \},
    \}

    let g:tagbar_type_css = {
        \ 'ctagstype' : 'Css',
        \ 'kinds'     : [
            \ 'c:classes',
            \ 's:selectors',
            \ 'i:identities'
        \ ]
    \ }

    let g:tagbar_type_ruby = {
        \ 'kinds' : [
            \ 'm:modules',
            \ 'c:classes',
            \ 'd:describes',
            \ 'C:contexts',
            \ 'f:methods',
            \ 'F:singleton methods'
        \ ]
    \ }

    let g:tagbar_type_elixir = {
        \ 'ctagstype' : 'elixir',
        \ 'kinds' : [
            \ 'f:functions',
            \ 'functions:functions',
            \ 'c:callbacks',
            \ 'd:delegates',
            \ 'e:exceptions',
            \ 'i:implementations',
            \ 'a:macros',
            \ 'o:operators',
            \ 'm:modules',
            \ 'p:protocols',
            \ 'r:records',
            \ 't:tests'
        \ ]
    \ }

    let g:tagbar_type_go = {
        \ 'ctagstype' : 'go',
        \ 'kinds'     : [
        \ 'p:package',
        \ 'i:imports',
        \ 'c:constants',
        \ 'v:variables',
        \ 't:types',
        \ 'n:interfaces',
        \ 'w:fields',
        \ 'e:embedded',
        \ 'm:methods',
        \ 'r:constructor',
        \ 'f:functions'
        \ ],
        \ 'sro' : '.',
        \ 'kind2scope' : {
            \ 't' : 'ctype',
            \ 'n' : 'ntype'
        \ },
        \ 'scope2kind' : {
            \ 'ctype' : 't',
            \ 'ntype' : 'n'
        \ },
        \ 'ctagsbin'  : "~/go/bin/gotags",
        \ 'ctagsargs' : '-sort -silent'
    \ }

    let g:tagbar_type_make = {
        \ 'kinds':[
            \ 'm:macros',
            \ 't:targets'
        \ ]
    \ }

    let g:tagbar_type_markdown = {
      \ 'ctagstype' : 'markdown',
      \ 'kinds' : [
          \ 'h:Heading_L1',
          \ 'i:Heading_L2',
          \ 'k:Heading_L3'
      \ ]
    \ }

    let g:tagbar_type_ps1 = {
      \ 'ctagstype' : 'powershell',
      \ 'kinds'     : [
        \ 'f:function',
        \ 'i:filter',
        \ 'a:alias'
      \ ]
    \ }

    let g:tagbar_type_rust = {
      \ 'ctagstype' : 'rust',
      \ 'kinds' : [
          \'T:types,type definitions',
          \'f:functions,function definitions',
          \'g:enum,enumeration names',
          \'s:structure names',
          \'m:modules,module names',
          \'c:consts,static constants',
          \'t:traits,traits',
          \'i:impls,trait implementations',
      \ ]
    \ }

    let g:tagbar_type_typescript = {
      \ 'ctagstype': 'typescript',
      \ 'kinds': [
        \ 'c:classes',
        \ 'n:modules',
        \ 'f:functions',
        \ 'v:variables',
        \ 'v:varlambdas',
        \ 'm:members',
        \ 'i:interfaces',
        \ 'e:enums',
      \ ]
    \ }

    let g:tagbar_type_xsd = {
      \ 'ctagstype' : 'XSD',
      \ 'kinds'     : [
          \ 'e:elements',
          \ 'c:complexTypes',
          \ 's:simpleTypes'
      \ ]
    \ }

    let g:tagbar_type_xslt = {
      \ 'ctagstype' : 'xslt',
      \ 'kinds' : [
        \ 'v:variables',
        \ 't:templates'
      \ ]
    \ }
  endif
endif
