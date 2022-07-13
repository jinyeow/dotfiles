" ------------------"
" => COMMANDS       "
" ------------------"

" :Chomp trailing whitespace
command! Chomp silent! normal! :%s/\s\+$//<CR>

" Split XML/HTML from a single-line to multi-line
" command! HTMLSplit normal! cit<CR><C-r>"<CR><ESC>
" command! HTMLSplit normal! :s;>\s*<;>\r<;g<CR>='[

" :SwapLine [line] will swap the current line with the given line number.
" NOTE: :SwapLine will overwrite the line below if given a count that is the
" same as the line number of the current line.
command! -count SwapLine silent! normal! msyy<count>ggPjdd`sVpms

" :SwapRel{Next,Prev} will swap lines relative to the current line
command! -count SwapRelNext silent! normal! msyy<count>jPjdd`sVpms
command! -count SwapRelPrev silent! normal! msyy<count>kpkdd`sVpms

" :Swap{Next,Prev}. Swaps the current line with the next/previous line
command! SwapNext silent! normal! :SwapRelNext 1<CR>
command! SwapPrev silent! normal! :SwapRelPrev 1<CR>

" Scroll/cursor bind the current window and the previous window
" So they move together like in vimdiff
command! BindOn set scrollbind cursorbind | wincmd p |
  \ set scrollbind cursorbind | wincmd p
command! BindOff set noscrollbind nocursorbind | wincmd p |
  \ set noscrollbind nocursorbind | wincmd p

" Creates a nice underline
command! Underline silent! normal! yypVr-
