

scriptencoding utf-8

if exists("g:loaded_vimconsole")
  finish
endif
let g:loaded_vimconsole = 1

let s:save_cpo = &cpo
set cpo&vim

let g:vimconsole#height = 6

command! -nargs=0 VimConsoleOpen  :call vimconsole#winopen()
command! -nargs=0 VimConsoleClose  :call vimconsole#winclose()
command! -nargs=0 VimConsoleClear  :call vimconsole#clear()
command! -nargs=0 VimConsoleRedraw :call vimconsole#redraw()
command! -nargs=0 VimConsoleTest   :call vimconsole#test()
command! -nargs=1 -complete=expression VimConsoleLog     :call vimconsole#log(<args>)
command! -nargs=1 -complete=expression VimConsoleError   :call vimconsole#error(<args>)

let &cpo = s:save_cpo
finish

