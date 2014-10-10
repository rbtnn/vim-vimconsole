
let s:TYPE_STRING = type('')
let s:TYPE_ERROR = 6
let s:TYPE_WARN = 7
let s:TYPE_PROMPT = 8

let s:PROMPT_STRING = 'VimConsole>'
let s:PROMPT_STRING_PATTERN = '^' . s:PROMPT_STRING
let s:FILETYPE = 'vimconsole'

augroup vimconsole
  autocmd!
  autocmd TextChanged * :call <sid>text_changed()
augroup END

function! s:text_changed()
  if &filetype is# s:FILETYPE
    let curr_session = s:session()
    let curr_session['input_str'] = ''
    let m = matchlist(getline('$'), s:PROMPT_STRING_PATTERN . '\(.*\)$')
    if ! empty(m)
      let curr_session['input_str'] = m[1]
    endif
    let save_line = getline(".")
    let save_cursor = getpos(".")
    let lines = join(vimconsole#buflines(), "\n") 
    silent % delete _
    silent put=lines
    silent 1 delete _
    call setpos('.', save_cursor)
    call setline('.', save_line)
  endif
endfunction
function! s:session()
  if g:vimconsole#session_type is# 't:'
    let t:vimconsole = get(t:,'vimconsole',{})
    return t:vimconsole
  elseif g:vimconsole#session_type is# 'g:'
    let g:vimconsole = get(g:,'vimconsole',{})
    return g:vimconsole
  else
    let t:vimconsole = get(t:,'vimconsole',{})
    return t:vimconsole
  endif
endfunction
function! s:object(...)
  let curr_session = s:session()

  let message_queue = deepcopy(get(curr_session,'message_queue',[]))
  if !empty(message_queue)
    let curr_session.message_queue = []
    for x in message_queue
      call s:add_log(s:TYPE_STRING,type(x),x,[])
    endfor
  endif

  if 0 < a:0
    let curr_session.objs = get(curr_session,'objs',[]) + [ a:1 ]
    let objs_len = len(curr_session.objs)
    let n = g:vimconsole#maximum_caching_objects_count
    let n = n <= 0 ? 0 : n
    let n = objs_len < n ? objs_len : n
    let curr_session.objs = curr_session.objs[(objs_len - n):]
  endif
  return get(curr_session,'objs',[])
endfunction
function! s:is_vimconsole_window(bufnr)
  return ( getbufvar(a:bufnr,'&filetype') ==# s:FILETYPE ) && ( getbufvar(a:bufnr,'vimconsole') )
endfunction
function! s:hook_events(hook_type,context)
  let curr_session = s:session()
  try
    if ! get(curr_session,'is_hooking',0)
      let curr_session.is_hooking = 1
      if has_key(g:vimconsole#hooks,a:hook_type)
        call g:vimconsole#hooks[(a:hook_type)](a:context)
      endif
      if -1 != index(['on_logged'],a:hook_type)
        if g:vimconsole#auto_redraw
          call vimconsole#redraw()
        endif
      endif
    endif
  finally
    let curr_session.is_hooking = 0
  endtry
endfunction
function! s:add_log(true_type,false_type,value,list)
  if 0 < len(a:list)
    call s:object({ 'type' : a:true_type, 'value' : call('printf',[(a:value)]+a:list) })
  else
    call s:object({ 'type' : a:false_type, 'value' : deepcopy(a:value) })
  endif
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
    try
      let lines += split(PrettyPrint(a:obj.value),"\n")
    catch
      let lines +=  [ '{' ]
      for key in keys(a:obj.value)
        let lines += [ '  ' . printf("'%s' : %s", key, string(a:obj.value[key])) . ',' ]
      endfor
      let lines += [ '}' ]
    endtry
  elseif type([]) == a:obj.type
    try
      let lines += split(PrettyPrint(a:obj.value),"\n")
    catch
      let lines +=  [ '[' ]
      for e in a:obj.value
        let lines += [ '  ' . string(e) . ',' ]
        unlet e
      endfor
      let lines += [ ']' ]
    endtry
  elseif type(0.0) == a:obj.type
    let lines += [ string(a:obj.value) ]
  elseif type(0) == a:obj.type
    let lines += [ string(a:obj.value) ]
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

  return lines
endfunction

function! s:key_cr()
  if s:is_vimconsole_window(bufnr('%'))
    let m = matchlist(getline('.'), s:PROMPT_STRING_PATTERN . '\(.*\)$')
    if ! empty(m)
      let input_str = m[1]
      if line('.') is line('$')
        let curr_session = s:session()
        let curr_session['input_str'] = ''
      endif
      call vimconsole#execute_on_prompt(input_str)
    endif
  endif
endfunction
function! s:key_c_n()
  normal 0
  call search(s:PROMPT_STRING_PATTERN, 'w')
  normal 0f>
endfunction
function! s:key_c_p()
  normal 0
  call search(s:PROMPT_STRING_PATTERN, 'bw')
  normal 0f>
endfunction
function! s:key_i_bs()
  if &l:filetype is# s:FILETYPE
    if len(s:PROMPT_STRING) < (getpos('.')[2] + getpos('.')[3] - 1)
      return "\<bs>"
    else
      return ''
    endif
  endif
endfunction
function! s:key_i_del()
  if &l:filetype is# s:FILETYPE
    if len(s:PROMPT_STRING) < (getpos('.')[2] + getpos('.')[3] - 1)
      return "\<del>"
    else
      return ''
    endif
  endif
endfunction

function! vimconsole#execute_on_prompt(input)
  if ! empty(a:input)
    call s:add_log(s:TYPE_PROMPT, s:TYPE_PROMPT, (s:PROMPT_STRING . a:input), [])

    let is_vimcon = s:is_vimconsole_window(winbufnr(0))

    if is_vimcon
      for winnr in range(1, winnr('$'))
        if winbufnr(winnr) == bufnr('#')
          execute winnr . "wincmd w"
        endif
      endfor
    endif

    try
      let F = function(g:vimconsole#eval_function_name)
      call vimconsole#log(F(a:input))
    catch
      call vimconsole#error(join([ v:exception, v:throwpoint ], "\n"))
    endtry

    if is_vimcon
      for winnr in range(1, winnr('$'))
        if s:is_vimconsole_window(winbufnr(winnr))
          execute winnr . "wincmd w"
          call vimconsole#bufenter()
          break
        endif
      endfor
    endif
  endif
endfunction
function! vimconsole#save_session(path)
  let path = expand(a:path == "" ? '~/.vimconsole_session' : a:path)
  silent! call writefile([
        \   printf("%s\t%s", 'g:vimconsole', string(get(g:, 'vimconsole', {}))),
        \   printf("%s\t%s", 't:vimconsole', string(get(t:, 'vimconsole', {}))),
        \   printf("%s\t%s", 'g:vimconsole#auto_redraw', string(g:vimconsole#auto_redraw)),
        \   printf("%s\t%s", 'g:vimconsole#enable_quoted_string', string(g:vimconsole#enable_quoted_string)),
        \   printf("%s\t%s", 'g:vimconsole#eval_function_name', string(g:vimconsole#eval_function_name)),
        \   printf("%s\t%s", 'g:vimconsole#height', string(g:vimconsole#height)),
        \   printf("%s\t%s", 'g:vimconsole#maximum_caching_objects_count', string(g:vimconsole#maximum_caching_objects_count)),
        \   printf("%s\t%s", 'g:vimconsole#no_default_key_mappings', string(g:vimconsole#no_default_key_mappings)),
        \   printf("%s\t%s", 'g:vimconsole#session_type', string(g:vimconsole#session_type)),
        \   printf("%s\t%s", 'g:vimconsole#split_rule', string(g:vimconsole#split_rule)),
        \   printf("%s\t%s", 'g:vimconsole#width', string(g:vimconsole#width)),
        \ ], path)
endfunction
function! vimconsole#load_session(path)
  let path = expand(a:path == "" ? '~/.vimconsole_session' : a:path)
  if filereadable(path)
    for line in readfile(path)
      let m = matchlist(line, '^\([^\t]*\)\t\(.*\)$')
      if !empty(m)
        if m[1] == 'g:vimconsole'
          let g:vimconsole = eval(m[2])
        elseif m[1] == 't:vimconsole'
          let t:vimconsole = eval(m[2])
        elseif m[1] == 'g:vimconsole#auto_redraw'
          let g:vimconsole#auto_redraw = eval(m[2])
        elseif m[1] == 'g:vimconsole#enable_quoted_string'
          let g:vimconsole#enable_quoted_string = eval(m[2])
        elseif m[1] == 'g:vimconsole#eval_function_name'
          let g:vimconsole#eval_function_name = eval(m[2])
        elseif m[1] == 'g:vimconsole#height'
          let g:vimconsole#height = eval(m[2])
        elseif m[1] == 'g:vimconsole#maximum_caching_objects_count'
          let g:vimconsole#maximum_caching_objects_count = eval(m[2])
        elseif m[1] == 'g:vimconsole#no_default_key_mappings'
          let g:vimconsole#no_default_key_mappings = eval(m[2])
        elseif m[1] == 'g:vimconsole#session_type'
          let g:vimconsole#session_type = eval(m[2])
        elseif m[1] == 'g:vimconsole#split_rule'
          let g:vimconsole#split_rule = eval(m[2])
        elseif m[1] == 'g:vimconsole#width'
          let g:vimconsole#width = eval(m[2])
        endif
      endif
    endfor
  endif
endfunction
function! vimconsole#clear()
  let curr_session = s:session()
  let curr_session.objs = []
  call vimconsole#redraw()
endfunction
function! vimconsole#assert(expr,obj,...)
  if a:expr
    call s:add_log(s:TYPE_STRING,type(a:obj),a:obj,a:000)
  endif
  call s:hook_events('on_logged',{ 'tag' : 'vimconsole#assert' })
endfunction
function! vimconsole#log(obj,...)
  call s:add_log(s:TYPE_STRING,type(a:obj),a:obj,a:000)
  call s:hook_events('on_logged',{ 'tag' : 'vimconsole#log' })
endfunction
function! vimconsole#warn(obj,...)
  call s:add_log(s:TYPE_WARN,s:TYPE_WARN,a:obj,a:000)
  call s:hook_events('on_logged',{ 'tag' : 'vimconsole#warn' })
endfunction
function! vimconsole#error(obj,...)
  call s:add_log(s:TYPE_ERROR,s:TYPE_ERROR,a:obj,a:000)
  call s:hook_events('on_logged',{ 'tag' : 'vimconsole#error' })
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
function! vimconsole#buflines()
  let rtn = []
  let reserved_lines_len = len(rtn)
  let start = reserved_lines_len
  for obj in s:object()
    let lines = s:object2lines(obj)
    let obj.start = start + 1
    let obj.last = start + len(lines)
    let rtn += lines
    let start = obj.last
  endfor
  let curr_session = s:session()
  let rtn += [ s:PROMPT_STRING . get(curr_session,'input_str','') ]
  return rtn
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

      call s:hook_events('on_pre_redraw',{ 'tag' : 'vimconsole#redraw' })

      let lines =join(vimconsole#buflines(), "\n") 
      silent % delete _
      silent put=lines
      silent 1 delete _

      call s:hook_events('on_post_redraw',{ 'tag' : 'vimconsole#redraw' })
    endif
  endfor
  execute curr_winnr . "wincmd w"
endfunction
function! vimconsole#foldtext()
  return '  +' . printf('%d lines: ', v:foldend - v:foldstart + 1) . getline(v:foldstart)[3:]
endfunction
function! vimconsole#bufenter()
  call vimconsole#redraw()
endfunction
function! vimconsole#define_commands()
  command! -nargs=0 -bar -bang VimConsoleOpen   :call vimconsole#winopen(<q-bang>)
  command! -nargs=0 -bar -bang VimConsoleRedraw :call vimconsole#redraw(<q-bang>)
  command! -nargs=0 -bar VimConsoleClose  :call vimconsole#winclose()
  command! -nargs=0 -bar VimConsoleClear  :call vimconsole#clear()
  command! -nargs=0 -bar VimConsoleToggle :call vimconsole#wintoggle()
  command! -nargs=1 -complete=expression VimConsoleLog     :call vimconsole#log(<args>)
  command! -nargs=1 -complete=expression VimConsoleError   :call vimconsole#error(<args>)
  command! -nargs=1 -complete=expression VimConsoleWarn    :call vimconsole#warn(<args>)
  command! -nargs=? -complete=file -bar VimConsoleSaveSession   :call vimconsole#save_session(<q-args>)
  command! -nargs=? -complete=file -bar VimConsoleLoadSession   :call vimconsole#load_session(<q-args>)
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
    let width = type(g:vimconsole#width) is type(0) ? g:vimconsole#width : eval(g:vimconsole#width) 
    let height = type(g:vimconsole#height) is type(0) ? g:vimconsole#height : eval(g:vimconsole#height) 
    if g:vimconsole#split_rule is# 'top'
      execute "wincmd K"
      execute 'resize ' . height
    elseif g:vimconsole#split_rule is# 'left'
      execute "wincmd H"
      execute 'vertical resize ' . width
    elseif g:vimconsole#split_rule is# 'right'
      execute "wincmd L"
      execute 'vertical resize ' . width
    else
      " defalut: bottom
      execute "wincmd J"
      execute 'resize ' . height
    endif
    let b:vimconsole = 1
    setlocal buftype=nofile
    setlocal nobuflisted
    setlocal noswapfile
    setlocal bufhidden=hide
    setlocal nospell
    setlocal foldmethod=manual
    execute 'setlocal filetype=' . s:FILETYPE

    nnoremap <silent><buffer> <Plug>(vimconsole_close) :<C-u>VimConsoleClose<cr>
    nnoremap <silent><buffer> <Plug>(vimconsole_clear) :<C-u>VimConsoleClear<cr>
    nnoremap <silent><buffer> <Plug>(vimconsole_redraw) :<C-u>VimConsoleRedraw<cr>
    nnoremap <silent><buffer> <Plug>(vimconsole_next_prompt) :<C-u>call <sid>key_c_n()<cr>
    nnoremap <silent><buffer> <Plug>(vimconsole_previous_prompt) :<C-u>call <sid>key_c_p()<cr>

    inoremap <silent><buffer><expr> <bs>   <sid>key_i_bs()
    inoremap <silent><buffer><expr> <del>  <sid>key_i_del()
    inoremap <silent><buffer>       <cr> <esc>:<C-u>call <sid>key_cr()<cr>
    nnoremap <silent><buffer>       <cr> <esc>:<C-u>call <sid>key_cr()<cr>
    if ! g:vimconsole#no_default_key_mappings
      nmap <silent><buffer> <C-p> <Plug>(vimconsole_previous_prompt)
      nmap <silent><buffer> <C-n> <Plug>(vimconsole_next_prompt)
    endif

    call clearmatches()
    call matchadd('Title', s:PROMPT_STRING_PATTERN)
    call matchadd('Comment', '^\[vimconsole].*$')

    call vimconsole#redraw()
  finally
    let &splitbelow = tmp
  endtry
  execute curr_winnr . "wincmd w"
endfunction

"  vim: set ts=2 sts=2 sw=2 ft=vim ff=unix :
