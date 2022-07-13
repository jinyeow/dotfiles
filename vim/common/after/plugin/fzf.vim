if (&runtimepath =~ 'fzf.vim')
  " Rails Models/Views/Controllers/Libs/Specs/Migrations as per CtrlP-Rails
  " Define only if inside a rails project.
  if InRailsProject()
    command! FzfModels execute 'FzfFiles app/models'
    command! FzfViews execute 'FzfFiles app/views'
    command! FzfControllers execute 'FzfFiles app/controllers'
    command! FzfLibs execute 'FzfFiles lib'
    command! FzfSpecs execute 'FzfFiles ' . (glob('test') == 'test' ? 'test' : 'spec')
    command! FzfMigrations execute 'FzfFiles db/migrate'
  endif

  nmap <Leader>ff :FzfFiles<CR>
  nmap <Leader>fF :FzfFiles ~<CR>
  nmap <Leader>fb :FzfBuffers<CR>
  nmap <Leader>fw :FzfWindows<CR>

  nmap <Leader>fg :FzfGitFiles<CR>
  nmap <Leader>fc :FzfCommits<CR>

  nmap <Leader>ft :FzfTags<CR>
  nmap <Leader>fT :FzfBTags<CR>

  nmap <Leader>fl :FzfLines<CR>
  nmap <Leader>fL :FzfBLines<CR>

  nmap <Leader>fM :FzfMarks<CR>
  nmap <Leader>fh :FzfHistory<CR>

  nmap <Leader>fs :FzfSnippets<CR>
endif

" function! s:find_root()
"   for vcs in ['.git', '.svn', '.hg']
"     let dir = finddir(vcs.'/..', ';')
"     if !empty(dir)
"       execute 'Files' dir
"       return
"     endif
"   endfor
"   Files
" endfunction
" command! FZFR call s:find_root()

" function! s:find_git_root()
"   return system('git rev-parse --show-toplevel 2> /dev/null')[:-2]
" endfunction
" command! ProjectFiles execute 'Files' s:find_git_root()

