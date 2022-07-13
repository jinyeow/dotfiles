let s:cpo_save = &cpo
set cpo&vim

syntax match csvHeading /\%1l\%(\%("\zs\%([^"]\|""\)*\ze"\)\|\%(\zs[^,"]*\ze\)\)/
highlight def link csvHeading Type


let &cpo = s:save_cpo
