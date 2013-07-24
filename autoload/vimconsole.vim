let s:TYPE_ERROR = 6
let s:TYPE_WARN = 7
let s:TYPE_PROMPT = 8
let s:PROMPT_LINE_NUM = 1
let s:PROMPT_STRING = 'VimConsole>'
let s:FILETYPE = 'vimconsole'

function! s:object(...)
  if 0 < a:0
    let n = g:vimconsole#maximum_caching_objects_count <= 0 ? 0 : g:vimconsole#maximum_caching_objects_count - 1
    let t:objs = ([ a:1 ] + get(t:,'objs',[]))[:(n)]
  endif
  return get(t:,'objs',[])
endfunction

function! s:is_vimconsole_window(bufnr)
  return ( getbufvar(a:bufnr,'&filetype') ==# s:FILETYPE ) && ( getbufvar(a:bufnr,'vimconsole') )
endfunction

function! s:logged_events(context)
  if has_key(g:vimconsole#hooks,'on_logged')
    call g:vimconsole#hooks.on_logged(a:context)
  endif
  if g:vimconsole#auto_redraw
    call vimconsole#redraw()
  endif
endfunction

function! s:add_log(true_type,false_type,value,list)
  if 0 < len(a:list)
    call s:object({ 'type' : a:true_type, 'value' : call('printf',[(a:value)]+a:list) })
  else
    call s:object({ 'type' : a:false_type, 'value' : deepcopy(a:value) })
  endif
endfunction

function! vimconsole#dump(path)
  silent! call writefile(split(s:get_log(),"\n"),a:path)
endfunction

function! vimconsole#clear()
  let t:objs = []
  call s:logged_events({ 'tag' : 'vimconsole#clear' })
endfunction

function! vimconsole#assert(expr,obj,...)
  if a:expr
    call s:add_log(type(""),type(a:obj),a:obj,a:000)
  endif
  call s:logged_events({ 'tag' : 'vimconsole#assert' })
endfunction

function! vimconsole#log(obj,...)
  call s:add_log(type(""),type(a:obj),a:obj,a:000)
  call s:logged_events({ 'tag' : 'vimconsole#log' })
endfunction

function! vimconsole#warn(obj,...)
  call s:add_log(s:TYPE_WARN,s:TYPE_WARN,a:obj,a:000)
  call s:logged_events({ 'tag' : 'vimconsole#warn' })
endfunction

function! vimconsole#error(obj,...)
  call s:add_log(s:TYPE_ERROR,s:TYPE_ERROR,a:obj,a:000)
  call s:logged_events({ 'tag' : 'vimconsole#error' })
endfunction

function! vimconsole#wintoggle()
  let close_flag = 0
  for winnr in range(1,winnr('$'))
    let bufnr = winbufnr(winnr)
    if s:is_vimconsole_window(bufnr)
      execute winnr . "wincmd w"
      close
      let close_flag = 1
    endif
  endfor
  if ! close_flag
    call vimconsole#winopen()
  endif
endfunction

function! vimconsole#is_open()
  for winnr in range(1,winnr('$'))
    let bufnr = winbufnr(winnr)
    if s:is_vimconsole_window(bufnr)
      return 1
    endif
  endfor
  return 0
endfunction

function! vimconsole#winclose()
  for winnr in range(1,winnr('$'))
    let bufnr = winbufnr(winnr)
    if s:is_vimconsole_window(bufnr)
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
  elseif type(0) == a:obj.type
    let lines += [ a:obj.value ]
  elseif s:TYPE_ERROR == a:obj.type || s:TYPE_WARN == a:obj.type
    if empty(a:obj.value)
      let lines += [""]
    else
      let lines += split(a:obj.value,"\n")
    endif
  elseif s:TYPE_PROMPT == a:obj.type
    let lines += [ a:obj.value ]
  elseif type('') == a:obj.type
    if g:vimconsole#enable_quoted_string
      let lines += map(split(a:obj.value,"\n"),'string(v:val)')
    else
      let lines += split(a:obj.value,"\n")
    endif
  else
    let lines += map(split(a:obj.value,"\n"),'string(v:val)')
  endif
  if g:vimconsole#plain_mode
    return lines
  else
    return [printf('%2s-%s', a:obj.type, get(lines,0,''))] + map(lines[1:],'printf("%2s|%s", a:obj.type, v:val)')
  endif
endfunction

function! vimconsole#at(...)
  let line_num = 0 < a:0 ? a:1 : line(".")
  if type(line_num) == type(0)
    for obj in s:object()
      if obj.start <= line_num && line_num <= obj.last
        return deepcopy(obj.value)
      endif
    endfor
  endif
  return {}
endfunction

function! s:get_log()
  let rtn = [ s:PROMPT_STRING ]
  let reserved_lines_len = len(rtn)
  let start = reserved_lines_len
  for obj in ( g:vimconsole#desending ? reverse( copy(s:object()) ) : s:object() )
    let lines = s:object2lines(obj)
    let obj.start = start + 1
    let obj.last = start + len(lines)
    let rtn += lines
    let start = obj.last
  endfor
  return join(rtn,"\n")
endfunction

function! vimconsole#redraw(...)
  let bang = 0 < a:0 ? ( a:1 ==# '!' ) : 0
  let curr_winnr = winnr()
  for winnr in range(1,winnr('$'))
    let bufnr = winbufnr(winnr)
    if s:is_vimconsole_window(bufnr)
      if bang
        call vimconsole#clear()
      endif
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
    let line = getline('.')
    let m = matchlist(line, '^' . s:PROMPT_STRING . '\(.*\)$')
    if ! empty(m)
      if ! empty(m[1])
        if g:vimconsole#desending
          call s:add_log(s:TYPE_PROMPT,s:TYPE_PROMPT,line,[])
          call vimconsole#log(eval(m[1]))
        else
          call vimconsole#log(eval(m[1]))
          call s:add_log(s:TYPE_PROMPT,s:TYPE_PROMPT,line,[])
        endif
        call setline(s:PROMPT_LINE_NUM, s:PROMPT_STRING)
        call vimconsole#bufenter()
      endif
    endif
  endif
endfunction

function! s:define_key_mappings()
  inoremap <silent><buffer> <cr> <esc>:<C-u>call <sid>i_key_cr()<cr>
  nnoremap <silent><buffer> <cr> <esc>:<C-u>call <sid>i_key_cr()<cr>
  nnoremap <silent><buffer> <Plug>(vimconsole_close) :<C-u>VimConsoleClose<cr>
  nnoremap <silent><buffer> <Plug>(vimconsole_clear) :<C-u>VimConsoleClear<cr>
  nnoremap <silent><buffer> <Plug>(vimconsole_redraw) :<C-u>VimConsoleRedraw<cr>
endfunction

function! s:define_highlight_syntax()
  " containedin=ALL
  execute "syn match   vimconsolePromptString  '^" . s:PROMPT_STRING . "' containedin=ALL"
  syn match   vimconsoleHidden              '^..\(-\||\)' containedin=ALL
  " normal
  syn match   vimconsolePromptInputString   '^\%1l.*$'
  syn match   vimconsoleNumber      /^ 0\(-\||\).*$/
  syn match   vimconsoleString      /^ 1\(-\||\).*$/
  syn match   vimconsoleFuncref     /^ 2\(-\||\).*$/
  syn match   vimconsoleList        /^ 3\(-\||\).*$/
  syn match   vimconsoleDictionary  /^ 4\(-\||\).*$/
  syn match   vimconsoleFloat       /^ 5\(-\||\).*$/
  syn match   vimconsoleError       /^ 6\(-\||\).*$/
  syn match   vimconsoleWarning     /^ 7\(-\||\).*$/
  syn match   vimconsolePrompt      /^ 8\(-\||\).*$/
  "
  hi! def link vimconsolePromptInputString     Title
  hi! def link vimconsolePromptString          SpecialKey
  hi! def link vimconsoleNumber     Normal
  hi! def link vimconsoleString     Normal
  hi! def link vimconsoleFuncref    Normal
  hi! def link vimconsoleList       Normal
  hi! def link vimconsoleDictionary Normal
  hi! def link vimconsoleFloat      Normal
  hi! def link vimconsoleFloat      Normal
  hi! def link vimconsolePrompt     Title
  "
  if g:vimconsole#plain_mode
    hi! def link vimconsoleHidden     Normal
    hi! def link vimconsoleError      Normal
    hi! def link vimconsoleWarning    Normal
  else
    hi! def link vimconsoleHidden     Ignore
    hi! def link vimconsoleError      Error
    hi! def link vimconsoleWarning    WarningMsg
  endif
endfunction

function! vimconsole#winopen(...)
  let bang = 0 < a:0 ? ( a:1 ==# '!' ) : 0
  let curr_winnr = winnr()
  if vimconsole#is_open()
    if bang
      call vimconsole#winclose()
    else
      return 0
    endif
  endif
  let tmp = &splitbelow
  try
    new
    if g:vimconsole#split_rule ==# 'top'
      execute "wincmd K"
      execute 'resize ' . g:vimconsole#height
    elseif g:vimconsole#split_rule ==# 'left'
      execute "wincmd H"
      execute 'vertical resize ' . g:vimconsole#width
    elseif g:vimconsole#split_rule ==# 'right'
      execute "wincmd L"
      execute 'vertical resize ' . g:vimconsole#width
    else
      " defalut: bottom
      execute "wincmd J"
      execute 'resize ' . g:vimconsole#height
    endif
    let b:vimconsole = 1
    setlocal buftype=nofile nobuflisted noswapfile bufhidden=hide
    execute 'setlocal filetype=' . s:FILETYPE
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

