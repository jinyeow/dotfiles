if exists("g:loaded_devdocs") || &compatible
  finish
endif
let g:loaded_devdocs = 1

let s:save_cpo = &cpo
set cpo&vim

" NOTE: possibly move this into an environment.vim ?
" Define a global variable containing the current environment's name
" if it hasn't been already defined.
if !exists('g:env')
	if has('win64') || has('win32') || has('win16')
		let g:env = 'WINDOWS'
	else
		let g:env = toupper(substitute(system('uname'), '\n', '', ''))
	endif
endif

" Optional cross-platform part
" See https://gist.github.com/romainl/4df4cde3498fada91032858d7af213c2 for how to define 'g:env'
if g:env =~ 'DARWIN'
  let cmd = "open"
endif

if g:env =~ 'LINUX'
  let cmd = "xdg-open"
endif

if g:env =~ 'WINDOWS'
  let cmd = "start"
endif

let stub = cmd . " 'http://devdocs.io/?q="

command! -nargs=* DD silent! call system(len(split(<q-args>, ' ')) == 0 ?
  \ stub . &ft . ' ' . expand('<cword>') . "'" : len(split(<q-args>, ' ')) == 1 ?
  \ stub . &ft . ' ' . <q-args> . "'" : stub . <q-args> . "'")

nnoremap \dd :DD<CR>

" setlocal keywordprg=:DD

let &cpo = s:save_cpo
