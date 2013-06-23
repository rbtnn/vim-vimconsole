
let s:TYPE_ERROR = 6
let s:TYPE_WARN = 7
let s:PROMPT_LINE_NUM = 2
let s:PROMPT_STRING = '>'
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

function! s:logged_events(context)
  if has_key(g:vimconsole#hooks,'on_logged')
    call g:vimconsole#hooks.on_logged(a:context)
  endif
  if g:vimconsole#auto_redraw
    call vimconsole#redraw()
  endif
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
  call s:logged_events({ 'tag' : 'vimconsole#assert' })
endfunction

function! vimconsole#log(obj,...)
  if 0 < a:0
    let s:objects = [ { 'type' : type("") , 'value' : call('printf',[(a:obj)]+a:000) } ] + s:objects
  else
    let s:objects = [ { 'type' : type(a:obj) , 'value' : deepcopy(a:obj) } ] + s:objects
  endif
  call s:logged_events({ 'tag' : 'vimconsole#log' })
endfunction

function! vimconsole#warn(obj,...)
  if 0 < a:0
    let s:objects = [ { 'type' : s:TYPE_WARN, 'value' : call('printf',[(a:obj)]+a:000) } ] + s:objects
  else
    let s:objects = [ { 'type' : s:TYPE_WARN, 'value' : deepcopy(a:obj) } ] + s:objects
  endif
  call s:logged_events({ 'tag' : 'vimconsole#warn' })
endfunction

function! vimconsole#error(obj,...)
  if 0 < a:0
    let s:objects = [ { 'type' : s:TYPE_ERROR, 'value' : call('printf',[(a:obj)]+a:000) } ] + s:objects
  else
    let s:objects = [ { 'type' : s:TYPE_ERROR, 'value' : deepcopy(a:obj) } ] + s:objects
  endif
  call s:logged_events({ 'tag' : 'vimconsole#error' })
endfunction

function! vimconsole#wintoggle()
  let close_flag = 0
  for winnr in range(1,winnr('$'))
    let bufnr = winbufnr(winnr)
    if getbufvar(bufnr,'&filetype') ==# 'vimconsole'
      execute winnr . "wincmd w"
      close
      let close_flag = 1
    endif
  endfor

  if ! close_flag
    call vimconsole#winopen()
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
  if g:vimconsole#plain_mode
    return lines
  else
    return [printf('%2s-%s', a:obj.type, lines[0])] + map(lines[1:],'printf("%2s|%s", a:obj.type, v:val)')
  endif
endfunction

function! vimconsole#at(...)
  let line_num = 0 < a:0 ? a:1 : line(".")
  if type(line_num) == type(0)
    for obj in s:objects
      if obj.start <= line_num && line_num <= obj.last
        return deepcopy(obj.value)
      endif
    endfor
  endif
  return {}
endfunction

function! s:get_log()
  let rtn = [ 'dummy', 'dummy' ]
  let reserved_lines_len = len(rtn)
  let start = reserved_lines_len
  for obj in s:objects
    let lines = s:object2lines(obj)

    let obj.start = start + 1
    let obj.last = start + len(lines)

    let rtn += lines

    let start = obj.last
  endfor
  let rtn[0] = printf('-- Vim Console (%d objects / %d lines) --', len(s:objects), len(rtn) - reserved_lines_len )
  let rtn[1] = s:PROMPT_STRING
  return join(rtn,"\n")
endfunction

function! vimconsole#redraw()
  let curr_winnr = winnr()
  for winnr in range(1,winnr('$'))
    let bufnr = winbufnr(winnr)
    if getbufvar(bufnr,'&filetype') ==# 'vimconsole'
      execute winnr . "wincmd w"
      silent % delete _
      silent put=s:get_log()
      silent 1 delete _
    endif
  endfor
  execute curr_winnr . "wincmd w"
endfunction

function! vimconsole#foldtext()
  return '  +' . printf('%d lines: ', v:foldend - v:foldstart + 1) . getline(v:foldstart)[3:]
endfunction

function! vimconsole#bufenter()
  let prompt_line = getline(s:PROMPT_LINE_NUM)
  call vimconsole#redraw()
  if prompt_line =~# '^' . s:PROMPT_STRING
    call setline(s:PROMPT_LINE_NUM, prompt_line)
  else
    call setline(s:PROMPT_LINE_NUM, s:PROMPT_STRING)
  endif
  call cursor(s:PROMPT_LINE_NUM,len(getline(s:PROMPT_LINE_NUM))+1)
endfunction

function! s:i_key_cr()
  if line('.') == s:PROMPT_LINE_NUM
    let m = matchlist(getline('.'), '^' . s:PROMPT_STRING . '\(.*\)$')
    if ! empty(m)
      if ! empty(m[1])
        call vimconsole#log(eval(m[1]))
        call setline(s:PROMPT_LINE_NUM, s:PROMPT_STRING)
        call vimconsole#bufenter()
      endif
    endif
  endif
endfunction

function! s:define_key_mappings()
  inoremap <silent><buffer> <cr> <esc>:<C-u>call <sid>i_key_cr()<cr>
  nnoremap <silent><buffer> <cr> <esc>:<C-u>call <sid>i_key_cr()<cr>
endfunction

function! s:define_highlight_syntax()
  " containedin=ALL
  execute "syn match   vimconsolePromptString  '^" . s:PROMPT_STRING . "' containedin=ALL"
  syn match   vimconsoleHidden              '^..\(-\||\)' containedin=ALL
  " normal
  syn match   vimconsoleTitle               '^\%1l.*$'
  syn match   vimconsolePromptInputString   '^\%2l.*$'
  syn match   vimconsoleNumber      /^ 0\(-\||\).*$/
  syn match   vimconsoleString      /^ 1\(-\||\).*$/
  syn match   vimconsoleFuncref     /^ 2\(-\||\).*$/
  syn match   vimconsoleList        /^ 3\(-\||\).*$/
  syn match   vimconsoleDictionary  /^ 4\(-\||\).*$/
  syn match   vimconsoleFloat       /^ 5\(-\||\).*$/
  syn match   vimconsoleError       /^ 6\(-\||\).*$/
  syn match   vimconsoleWarning     /^ 7\(-\||\).*$/

  hi def link vimconsoleTitle                 Title
  hi def link vimconsolePromptInputString     Statement
  hi def link vimconsolePromptString          SpecialKey
  hi def link vimconsoleNumber     Normal
  hi def link vimconsoleString     Normal
  hi def link vimconsoleFuncref    Normal
  hi def link vimconsoleList       Normal
  hi def link vimconsoleDictionary Normal
  hi def link vimconsoleFloat      Normal
  hi def link vimconsoleFloat      Normal

  if g:vimconsole#plain_mode
    hi def link vimconsoleHidden     Normal
    hi def link vimconsoleError      Normal
    hi def link vimconsoleWarning    Normal
  else
    hi def link vimconsoleHidden     Ignore
    hi def link vimconsoleError      Error
    hi def link vimconsoleWarning    WarningMsg
  endif
endfunction

function! vimconsole#winopen()
  let curr_winnr = winnr()
  call vimconsole#winclose()
  let tmp = &splitbelow
  try
    setlocal splitbelow
    execute "wincmd b"
    new
    execute 'resize ' . g:vimconsole#height
    setlocal buftype=nofile nobuflisted noswapfile bufhidden=hide
    setlocal filetype=vimconsole
    augroup vimconsole
      autocmd!
      autocmd InsertEnter <buffer> call vimconsole#bufenter()
    augroup END
    if g:vimconsole#plain_mode
      setlocal foldmethod=manual
    else
      setlocal foldmethod=expr
      setlocal foldtext=vimconsole#foldtext()
      setlocal foldexpr=(getline(v:lnum)[2]==#'\|')?'=':'>1'
    endif
    call s:define_key_mappings()
    call s:define_highlight_syntax()
    call vimconsole#redraw()
    normal zm
  finally
    let &splitbelow = tmp
  endtry
  execute curr_winnr . "wincmd w"
endfunction

