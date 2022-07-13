"=================================================================
"   Mappings:                                                    =
"=================================================================

" <leader> key
let mapleader      = " "
let g:mapleader    = " "
let maplocalleader = "\\"

" alternate escapes
inoremap jj <esc>

" move vertically by visual line
" nnoremap j gj
" nnoremap k gk

" Vertical movement with cursor center of screen
" nnoremap j gjzz
" nnoremap k gkzz

" move to begging/end of line
map 0 ^

" unmap arrow keys
nnoremap <up> <nop>
nnoremap <down> <nop>
nnoremap <left> <nop>
nnoremap <right> <nop>

" Easy pane resizing
nnoremap <Up> <C-w>+
nnoremap <Down> <C-w>-
nnoremap <Left> <C-w><
nnoremap <Right> <C-w>>

" Buffer navigation
noremap <leader>p :bp<CR>
noremap <leader>n :bn<CR>
nnoremap <S-right> <ESC>:bn<CR>
nnoremap <S-left> <ESC>:bp<CR>

" Close buffer (NOTE: see functions.vim#s:Kwbd()
" noremap <leader>d :bd<CR>

" Retain visual selection after indenting
vnoremap < <gv
vnoremap > >gv
vnoremap <S-Tab> <gv
vnoremap <Tab> >gv

" Make Y behave like other capitals
nnoremap Y y$

" turn off search highlight
nnoremap <silent>  <space> :nohlsearch<CR>

" changes the default Vim regexes to sane/regular regex. or something.
nnoremap / /\v
vnoremap / /\v
nnoremap ? ?\v
vnoremap ? ?\v
nnoremap :s/ :s/\v

set gdefault " defaults substitutions globally on lines

" center screen when scrolling search results
nnoremap n nzvzz
nnoremap N Nzvzz
" not in use, slash.vim overwrites these
" nnoremap * *zvzz
" nnoremap # #zvzz

" Have the help split vertically instead of the default horizontally.
" cnoremap help vert help
cabbrev h vert h

if (has('nvim'))
  " Quit
  inoremap <C-Q> <ESC>:q<CR>
  nnoremap <C-Q> :q<CR>
  vnoremap <C-Q> <ESC>
endif

" Readline-style key bindings in command-line (excerpt from tpope/rsi.vim)
inoremap        <C-A> <C-O>^
inoremap   <C-X><C-A> <C-A>
cnoremap        <C-A> <Home>
cnoremap   <C-X><C-A> <C-A>

inoremap <expr> <C-B> getline('.')=~'^\s*$'&&col('.')>strlen(getline('.'))?"0\<Lt>C-D>\<Lt>Esc>kJs":"\<Lt>Left>"
cnoremap        <C-B> <Left>

inoremap <expr> <C-D> col('.')>strlen(getline('.'))?"\<Lt>C-D>":"\<Lt>Del>"
cnoremap <expr> <C-D> getcmdpos()>strlen(getcmdline())?"\<Lt>C-D>":"\<Lt>Del>"

inoremap <expr> <C-E> col('.')>strlen(getline('.'))<bar><bar>pumvisible()?"\<Lt>C-E>":"\<Lt>End>"

inoremap <expr> <C-F> col('.')>strlen(getline('.'))?"\<Lt>C-F>":"\<Lt>Right>"
cnoremap <expr> <C-F> getcmdpos()>strlen(getcmdline())?&cedit:"\<Lt>Right>"

if empty(mapcheck('<C-G>', 'c'))
  cmap <script> <C-G> <C-C>
endif

noremap! <expr> <SID>transposition getcmdpos()>strlen(getcmdline())?"\<Left>":getcmdpos()>1?'':"\<Right>"
noremap! <expr> <SID>transpose "\<BS>\<Right>".matchstr(getcmdline()[0 : getcmdpos()-2], '.$')
cmap <script> <C-T> <SID>transposition<SID>transpose

" #!! | Shebang
inoreabbrev <expr> #!! "#!/usr/bin/env" . (empty(&filetype) ? '' : ' '.&filetype)

" Buffer navigation
nnoremap gb :ls<CR>:buffer<Space>
nnoremap gB :ls<CR>:sbuffer<Space>
nnoremap ,b :buffer *
nnoremap ,B :sbuffer *
nnoremap ,a :b#<CR>
nnoremap ,A :sb#<CR>

" File navigation
nnoremap ,f :find *
nnoremap ,s :sfind *
nnoremap ,v :vert sfind *
nnoremap ,t :tabfind *
nnoremap ,F :find <C-R>=fnameescape(expand('%:p:h')).'/**/*'<CR>
nnoremap ,S :sfind <C-R>=fnameescape(expand('%:p:h')).'/**/*'<CR>
nnoremap ,V :vert sfind <C-R>=fnameescape(expand('%:p:h')).'/**/*'<CR>
nnoremap ,T :tabfind <C-R>=fnameescape(expand('%:p:h')).'/**/*'<CR>

" Quick search/replace
" SnR word under cursor in the current line
nnoremap <Space><Space> :'{,'}s/\<<C-r>=expand('<cword>')<CR>\>/

" SnR word under cursor in the current file
nnoremap <Space>%       :%s/\<<C-r>=expand('<cword>')<CR>\>/

" Sharing snippets
if has('unix') && executable('xclip')
  command! -range=% IX  <line1>,<line2>w !curl -F 'f:1=<-' ix.io | tr -d '\n' | xclip -i -selection clipboard
  " command! -range=% SP  <line1>,<line2>w !curl -F 'sprunge=<-' http://sprunge.us | tr -d '\n' | xclip -i -selection clipboard
  " command! -range=% CL  <line1>,<line2>w !curl -F 'clbin=<-' https://clbin.com | tr -d '\n' | xclip -i -selection clipboard
  " command! -range=% VP  <line1>,<line2>w !curl -F 'text=<-' http://vpaste.net | tr -d '\n' | xclip -i -selection clipboard
  " command! -range=% TB <line1>,<line2>w !nc termbin 9999 | tr -d '\n' | xclip -i -selection clipboard
endif

" Autoexpansion brackets ala delimitmate
" inoremap (<CR> (<CR>)<Esc>O
" inoremap {<CR> {<CR>}<Esc>O
" inoremap {; {<CR>};<Esc>O
" inoremap {, {<CR>},<Esc>O
" inoremap [<CR> [<CR>]<Esc>O
" inoremap [; [<CR>];<Esc>O
" inoremap [, [<CR>],<Esc>O

" Scratch buffer - See functions.vim for a better version ScratchEdit() + related cmds.
" command! SCV vnew | setlocal nobuflisted buftype=nofile bufhidden=wipe noswapfile
" command! SC new | setlocal nobuflisted buftype=nofile bufhidden=wipe noswapfile

" Symbol-based navigation
nnoremap ,j :tjump /
nnoremap ,p :ptjump /

nnoremap ,i :ilist /
nnoremap [I [I:ijump   <C-r><C-w><S-Left><Left><Left>
nnoremap ]I ]I:ijump   <C-r><C-w><S-Left><Left><Left>

nnoremap ,d :dlist /
nnoremap [D [D:djump   <C-r><C-w><S-Left><Left>
nnoremap ]D ]D:djump   <C-r><C-w><S-Left><Left>

" Like '<C-r><C-w>' but for the line under the cursor.
cnoremap <C-r><C-l> <C-r>=getline('.')<CR>
