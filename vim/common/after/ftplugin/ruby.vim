setlocal tabstop=2
setlocal softtabstop=2
setlocal shiftwidth=2

setlocal makeprg=ruby\ -c\ -T1\ -w\ %
setlocal errorformat+=%-GSyntax\ OK
setlocal errorformat+=%f:%l:%m
