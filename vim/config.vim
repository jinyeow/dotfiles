" vim:foldmethod=marker:foldlevel=0

" CREATED: 18/11/17 00:46
" UPDATED: 11/12/22

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

