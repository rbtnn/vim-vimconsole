
let s:TYPE_ERROR = 6
let s:objects = get(s:,'objects',[])

function! vimconsole#test()
  call vimconsole#clear()
  call vimconsole#log(123)
  call vimconsole#log("hoge\nfoo")
  call vimconsole#error("this is error message.")
  call vimconsole#log([ 1,2,3,4,5 ])
  call vimconsole#log(function('vimconsole#test'))
  call vimconsole#log(function('tr'))
  call vimconsole#log({ 'A' : 23, 'B' : { 'C' : 0.034 } })
endfunction

function! vimconsole#clear()
  let s:objects = []
endfunction

function! vimconsole#log(obj)
  let s:objects = [ { 'type' : type(a:obj) , 'value' : deepcopy(a:obj) } ] + s:objects
endfunction

function! vimconsole#error(obj)
  let s:objects = [ { 'type' : s:TYPE_ERROR, 'value' : deepcopy(a:obj) } ] + s:objects
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

function! s:object2lines(obj_id,obj)
  let format =  '%3d|%s|%s'
  let lines = []
  if type(function('tr')) == a:obj.type
    redir => hoge
    try
      execute 'function ' . matchstr(string(a:obj.value),"function('\\zs.*\\ze')")
    catch /.*/
      let a:obj.type = s:TYPE_ERROR
      let a:obj.value = v:exception . "\n" . v:throwpoint
      echo a:obj.value
    endtry
    redir END
    let lines += split(hoge,"\n")
  elseif type({}) == a:obj.type
    let lines +=  [ '{' ]
    for key in keys(a:obj.value)
      let lines += [ '  ' . printf('%s: %s', key, string(a:obj.value[key])) . ',' ]
    endfor
    let lines += [ '}' ]
  elseif type([]) == a:obj.type
    let lines +=  [ '[' ]
    for e in a:obj.value
      let lines += [ '  ' . string(e) . ',' ]
      unlet e
    endfor
    let lines += [ ']' ]
  elseif type("") == a:obj.type
    let lines += split(a:obj.value,"\n")
  elseif s:TYPE_ERROR == a:obj.type
    let lines += split(a:obj.value,"\n")
  else
    let lines += [ string(a:obj.value) ]
  endif
  return map(lines,'printf(format, a:obj_id, a:obj.type, v:val)')
endfunction

function! s:get_log()
  let rtn = [ printf('-- Vim Console (%d) --', len(s:objects)) ]
  for obj_id in range(0,len(s:objects)-1)
    let rtn += s:object2lines( obj_id, s:objects[obj_id])
  endfor
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

function! vimconsole#winopen()
  call vimconsole#winclose()
  let tmp = &splitbelow
  try
    setlocal splitbelow
    new
    setlocal buftype=nofile nobuflisted noswapfile bufhidden=hide
    setlocal filetype=vimconsole
    setlocal foldmethod=expr
    setlocal foldexpr=(getline(v:lnum-1)[:2]==#getline(v:lnum)[:2])?'=':'>1'
    call vimconsole#redraw()
    normal zm
  finally
    let &splitbelow = tmp
  endtry
endfunction
