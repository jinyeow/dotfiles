let g:rooter_change_directory_for_non_project_files = 'current'

let g:rooter_disable_map   = 1
let g:rooter_manual_only   = 0
let g:rooter_use_lcd       = 1
let g:rooter_silent_chdir  = 0
let g:rooter_resolve_links = 1

" Default patterns
let g:rooter_patterns = [
      \ 'Rakefile',
      \ 'mix.exs',
      \ 'Gemfile',
      \ '.projections.json',
      \ '.agignore',
      \ '.ignore',
      \ 'tags',
      \ 'Makefile',
      \ 'README.md',
      \ '.git',
      \ '.git/',
      \ '_darcs/',
      \ '.hg/',
      \ '.bzr/',
      \ '.svn/',
      \ 'tsconfig.json'
      \ ]
