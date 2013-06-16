
let s:TYPE_ERROR = 6
let s:TYPE_WARN = 7
let s:objects = get(s:,'objects',[])

function! vimconsole#test()
  call vimconsole#clear()
  call vimconsole#log(123)
  call vimconsole#log("hoge\nfoo")
  call vimconsole#error("this is error message.")
  call vimconsole#log([ 1,2,3,4,5 ])
  call vimconsole#log(function('vimconsole#test'))
  call vimconsole#log(function('tr'))
  call vimconsole#warn("this is warn message.")
  call vimconsole#assert(1,"(true) this is assert message.")
  call vimconsole#assert(0,"(false) this is assert message.")
  call vimconsole#warn("this is %s message.", 'warn')
  call vimconsole#log({ 'A' : 23, 'B' : { 'C' : 0.034 } })
endfunction

function! vimconsole#clear()
  let s:objects = []
endfunction

function! vimconsole#assert(expr,obj,...)
  if a:expr
    if 0 < a:0
      let s:objects = [ { 'type' : type("") , 'value' : call('printf',[(a:obj)]+a:000) } ] + s:objects
    else
      let s:objects = [ { 'type' : type(a:obj) , 'value' : deepcopy(a:obj) } ] + s:objects
    endif
  endif
endfunction

function! vimconsole#log(obj,...)
  if 0 < a:0
    let s:objects = [ { 'type' : type("") , 'value' : call('printf',[(a:obj)]+a:000) } ] + s:objects
  else
    let s:objects = [ { 'type' : type(a:obj) , 'value' : deepcopy(a:obj) } ] + s:objects
  endif
endfunction

function! vimconsole#warn(obj,...)
  if 0 < a:0
    let s:objects = [ { 'type' : s:TYPE_WARN, 'value' : call('printf',[(a:obj)]+a:000) } ] + s:objects
  else
    let s:objects = [ { 'type' : s:TYPE_WARN, 'value' : deepcopy(a:obj) } ] + s:objects
  endif
endfunction

function! vimconsole#error(obj,...)
  if 0 < a:0
    let s:objects = [ { 'type' : s:TYPE_ERROR, 'value' : call('printf',[(a:obj)]+a:000) } ] + s:objects
  else
    let s:objects = [ { 'type' : s:TYPE_ERROR, 'value' : deepcopy(a:obj) } ] + s:objects
  endif
endfunction

function! vimconsole#winclose()
  for winnr in range(1,winnr('$'))
    let bufnr = winbufnr(winnr)
    if getbufvar(bufnr,'&filetype') ==# 'vimconsole'
      execute winnr . "wincmd w"
      close
    endif
  endfor
endfunction

function! s:object2lines(obj)
  let lines = []
  if type(function('tr')) == a:obj.type
    redir => hoge
    try
      execute 'function ' . matchstr(string(a:obj.value),"function('\\zs.*\\ze')")
    catch /.*/
      echo string(a:obj.value)
    endtry
    redir END
    let lines += split(hoge,"\n")
  elseif type({}) == a:obj.type
    if exists('*PrettyPrint')
      let lines += split(PrettyPrint(a:obj.value),"\n")
    else
      let lines +=  [ '{' ]
      for key in keys(a:obj.value)
        let lines += [ '  ' . printf("'%s' : %s", key, string(a:obj.value[key])) . ',' ]
      endfor
      let lines += [ '}' ]
    endif
  elseif type([]) == a:obj.type
    if exists('*PrettyPrint')
      let lines += split(PrettyPrint(a:obj.value),"\n")
    else
      let lines +=  [ '[' ]
      for e in a:obj.value
        let lines += [ '  ' . string(e) . ',' ]
        unlet e
      endfor
      let lines += [ ']' ]
    endif
  elseif type("") == a:obj.type
    let lines += split(a:obj.value,"\n")
  elseif s:TYPE_ERROR == a:obj.type
    let lines += split(a:obj.value,"\n")
  elseif s:TYPE_WARN == a:obj.type
    let lines += split(a:obj.value,"\n")
  else
    let lines += [ string(a:obj.value) ]
  endif
  return [printf('%2s-%s', a:obj.type, lines[0])] + map(lines[1:],'printf("%2s|%s", a:obj.type, v:val)')
endfunction

function! s:get_log()
  let rtn = [ 'dummy' ]
  for obj in s:objects
    let rtn += s:object2lines(obj)
  endfor
  let rtn[0] = printf('-- Vim Console (%d objects / %d lines) --', len(s:objects), len(rtn) - 1 )
  return join(rtn,"\n")
endfunction

function! vimconsole#redraw()
  let curr_winnr = winnr()
  for winnr in range(1,winnr('$'))
    let bufnr = winbufnr(winnr)
    if getbufvar(bufnr,'&filetype') ==# 'vimconsole'
      execute winnr . "wincmd w"
      setlocal noreadonly
      silent % delete _
      silent put=s:get_log()
      silent 1 delete _
      setlocal readonly
    endif
  endfor
  execute curr_winnr . "wincmd w"
endfunction

function! vimconsole#foldtext()
  return '  +' . printf('%d lines: ', v:foldend - v:foldstart + 1) . getline(v:foldstart)[3:]
endfunction

function! vimconsole#winopen()
  call vimconsole#winclose()
  let tmp = &splitbelow
  try
    setlocal splitbelow
    execute "wincmd b"
    new
    execute 'resize ' . g:vimconsole#height
    setlocal buftype=nofile nobuflisted noswapfile bufhidden=hide
    setlocal filetype=vimconsole
    setlocal foldmethod=expr
    setlocal foldtext=vimconsole#foldtext()
    setlocal foldexpr=(getline(v:lnum)[2]==#'\|')?'=':'>1'
    call vimconsole#redraw()
    normal zm
  finally
    let &splitbelow = tmp
  endtry
endfunction

