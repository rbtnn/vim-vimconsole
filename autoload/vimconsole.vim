
let s:TYPE_ERROR = 6
let s:TYPE_WARN = 7
let s:TYPE_PROMPT = 8
let s:PROMPT_STRING = 'VimConsole>'
let s:PROMPT_STRING_PATTERN = '^\%(\|...\)' . s:PROMPT_STRING
let s:FILETYPE = 'vimconsole'

function! s:session() " {{{
  let t:vimconsole = get(t:,'vimconsole',{})
  return t:vimconsole
endfunction " }}}
function! s:object(...) " {{{
  let tab_session = s:session()
  if 0 < a:0
    let tab_session.objs = get(tab_session,'objs',[]) + [ a:1 ]
    let objs_len = len(tab_session.objs)
    let n = g:vimconsole#maximum_caching_objects_count
    let n = n <= 0 ? 0 : n
    let n = objs_len < n ? objs_len : n
    let tab_session.objs = tab_session.objs[(objs_len - n):]
  endif
  return get(tab_session,'objs',[])
endfunction " }}}
function! s:is_vimconsole_window(bufnr) " {{{
  return ( getbufvar(a:bufnr,'&filetype') ==# s:FILETYPE ) && ( getbufvar(a:bufnr,'vimconsole') )
endfunction " }}}
function! s:get_curr_prompt_line_num() " {{{
  if s:is_vimconsole_window(bufnr('%'))
    return line('.')
  else
    return 1
  endif
endfunction " }}}

function! s:hook_events(hook_type,context) " {{{
  let tab_session = s:session()
  try
    if ! get(tab_session,'is_hooking',0)
      let tab_session.is_hooking = 1
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
    let tab_session.is_hooking = 0
  endtry
endfunction " }}}

function! s:add_log(true_type,false_type,value,list) " {{{
  if 0 < len(a:list)
    call s:object({ 'type' : a:true_type, 'value' : call('printf',[(a:value)]+a:list) })
  else
    call s:object({ 'type' : a:false_type, 'value' : deepcopy(a:value) })
  endif
endfunction " }}}

function! vimconsole#dump(path) " {{{
  silent! call writefile(split(s:get_log(),"\n"),a:path)
endfunction " }}}
function! vimconsole#clear() " {{{
  let tab_session = s:session()
  let tab_session.objs = []
  call vimconsole#redraw()
endfunction " }}}

function! vimconsole#assert(expr,obj,...) " {{{
  if a:expr
    call s:add_log(type(""),type(a:obj),a:obj,a:000)
  endif
  call s:hook_events('on_logged',{ 'tag' : 'vimconsole#assert' })
endfunction " }}}
function! vimconsole#log(obj,...) " {{{
  call s:add_log(type(""),type(a:obj),a:obj,a:000)
  call s:hook_events('on_logged',{ 'tag' : 'vimconsole#log' })
endfunction " }}}
function! vimconsole#warn(obj,...) " {{{
  call s:add_log(s:TYPE_WARN,s:TYPE_WARN,a:obj,a:000)
  call s:hook_events('on_logged',{ 'tag' : 'vimconsole#warn' })
endfunction " }}}
function! vimconsole#error(obj,...) " {{{
  call s:add_log(s:TYPE_ERROR,s:TYPE_ERROR,a:obj,a:000)
  call s:hook_events('on_logged',{ 'tag' : 'vimconsole#error' })
endfunction " }}}
function! vimconsole#wintoggle() " {{{
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
endfunction " }}}
function! vimconsole#is_open() " {{{
  for winnr in range(1,winnr('$'))
    let bufnr = winbufnr(winnr)
    if s:is_vimconsole_window(bufnr)
      return 1
    endif
  endfor
  return 0
endfunction " }}}
function! vimconsole#winclose() " {{{
  for winnr in range(1,winnr('$'))
    let bufnr = winbufnr(winnr)
    if s:is_vimconsole_window(bufnr)
      execute winnr . "wincmd w"
      close
    endif
  endfor
endfunction " }}}

function! s:object2lines(obj) " {{{
  let lines = []

  if type(function('tr')) == a:obj.type
    " {{{
    redir => hoge
    try
      execute 'function ' . matchstr(string(a:obj.value),"function('\\zs.*\\ze')")
    catch /.*/
      echo string(a:obj.value)
    endtry
    redir END
    let lines += split(hoge,"\n")
    " }}}
  elseif type({}) == a:obj.type
    " {{{
    if exists('*PrettyPrint')
      let lines += split(PrettyPrint(a:obj.value),"\n")
    else
      let lines +=  [ '{' ]
      for key in keys(a:obj.value)
        let lines += [ '  ' . printf("'%s' : %s", key, string(a:obj.value[key])) . ',' ]
      endfor
      let lines += [ '}' ]
    endif
    " }}}
  elseif type([]) == a:obj.type
    " {{{
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
    " }}}
  elseif type(0.0) == a:obj.type
    " {{{
    let lines += [ string(a:obj.value) ]
    " }}}
  elseif type(0) == a:obj.type
    " {{{
    let lines += [ string(a:obj.value) ]
    " }}}
  elseif s:TYPE_ERROR == a:obj.type || s:TYPE_WARN == a:obj.type
    " {{{
    if empty(a:obj.value)
      let lines += [""]
    else
      let lines += split(a:obj.value,"\n")
    endif
    " }}}
  elseif s:TYPE_PROMPT == a:obj.type
    " {{{
    let lines += [ a:obj.value ]
    " }}}
  elseif type('') == a:obj.type
    " {{{
    if g:vimconsole#enable_quoted_string
      let lines += map(split(a:obj.value,"\n"),'string(v:val)')
    else
      let lines += split(a:obj.value,"\n")
    endif
    " }}}
  else
    " {{{
    let lines += map(split(a:obj.value,"\n"),'string(v:val)')
    " }}}
  endif

  if g:vimconsole#plain_mode
    return lines
  else
    return [printf('%2s-%s', a:obj.type, get(lines,0,''))] + map(lines[1:],'printf("%2s|%s", a:obj.type, v:val)')
  endif
endfunction " }}}
function! vimconsole#at(...) " {{{
  let line_num = 0 < a:0 ? a:1 : line(".")
  if type(line_num) == type(0)
    for obj in s:object()
      if obj.start <= line_num && line_num <= obj.last
        return deepcopy(obj.value)
      endif
    endfor
  endif
  return {}
endfunction " }}}
function! s:get_log() " {{{
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
  let rtn += [ s:PROMPT_STRING ]
  return join(rtn,"\n")
endfunction " }}}

function! vimconsole#redraw(...) " {{{
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

      silent % delete _
      silent put=s:get_log()
      silent 1 delete _

      call s:hook_events('on_post_redraw',{ 'tag' : 'vimconsole#redraw' })
    endif
  endfor
  execute curr_winnr . "wincmd w"
endfunction " }}}
function! vimconsole#foldtext() " {{{
  return '  +' . printf('%d lines: ', v:foldend - v:foldstart + 1) . getline(v:foldstart)[3:]
endfunction " }}}
function! vimconsole#bufenter() " {{{
  call vimconsole#redraw()
  " move the last prompt line.
  normal G
endfunction " }}}

function! s:key_cr() " {{{
  if line('.') == s:get_curr_prompt_line_num()
    let m = matchlist(getline('.'), s:PROMPT_STRING_PATTERN . '\(.*\)$')
    if ! empty(m)
      let input_str = m[1]

      if ! empty(input_str)
        call s:add_log(s:TYPE_PROMPT, s:TYPE_PROMPT, (s:PROMPT_STRING . input_str), [])
        try
          let F = function(g:vimconsole#eval_function_name)
          call vimconsole#log(F(input_str))
        catch
          call vimconsole#error(join([ v:exception, v:throwpoint ], "\n"))
        endtry

        call vimconsole#bufenter()
      endif

    endif
  endif
endfunction " }}}

function! s:key_c_n() " {{{
  normal 0
  call search(s:PROMPT_STRING_PATTERN, 'w')
  normal 0f>
endfunction " }}}
function! s:key_c_p() " {{{
  normal 0
  call search(s:PROMPT_STRING_PATTERN, 'bw')
  normal 0f>
endfunction " }}}

function! vimconsole#define_plug_keymappings() " {{{
  nnoremap <silent><buffer> <Plug>(vimconsole_close) :<C-u>VimConsoleClose<cr>
  nnoremap <silent><buffer> <Plug>(vimconsole_clear) :<C-u>VimConsoleClear<cr>
  nnoremap <silent><buffer> <Plug>(vimconsole_redraw) :<C-u>VimConsoleRedraw<cr>
  nnoremap <silent><buffer> <Plug>(vimconsole_next_prompt) :<C-u>call <sid>key_c_n()<cr>
  nnoremap <silent><buffer> <Plug>(vimconsole_previous_prompt) :<C-u>call <sid>key_c_p()<cr>
endfunction " }}}
function! vimconsole#define_default_keymappings() " {{{
  inoremap <silent><buffer> <cr> <esc>:<C-u>call <sid>key_cr()<cr>
  nnoremap <silent><buffer> <cr> <esc>:<C-u>call <sid>key_cr()<cr>
  if ! g:vimconsole#no_default_key_mappings
    nmap <silent><buffer> <C-p> <Plug>(vimconsole_previous_prompt)
    nmap <silent><buffer> <C-n> <Plug>(vimconsole_next_prompt)
  endif
endfunction " }}}
function! vimconsole#define_syntax() " {{{
  let curr_winnr = winnr()
  for winnr in range(1,winnr('$'))
    let bufnr = winbufnr(winnr)
    if s:is_vimconsole_window(bufnr)
      execute winnr . "wincmd w"

      " containedin=ALL
      execute "syn match   vimconsolePromptString  '^" . s:PROMPT_STRING . "' containedin=ALL"
      "                                                         ^-- Is not s:PROMPT_STRING_PATTERN !

      syn match   vimconsoleHidden              '^..\(-\||\)' containedin=ALL
      " normal
      syn match   vimconsoleNumber      /^ 0\(-\||\).*$/
      syn match   vimconsoleString      /^ 1\(-\||\).*$/
      syn match   vimconsoleFuncref     /^ 2\(-\||\).*$/
      syn match   vimconsoleList        /^ 3\(-\||\).*$/
      syn match   vimconsoleDictionary  /^ 4\(-\||\).*$/
      syn match   vimconsoleFloat       /^ 5\(-\||\).*$/
      syn match   vimconsoleError       /^ 6\(-\||\).*$/
      syn match   vimconsoleWarning     /^ 7\(-\||\).*$/
      syn match   vimconsolePrompt      /^ 8\(-\||\).*$/

    endif
  endfor
  execute curr_winnr . "wincmd w"
endfunction " }}}
function! vimconsole#define_highlight() " {{{
  let curr_winnr = winnr()
  for winnr in range(1,winnr('$'))
    let bufnr = winbufnr(winnr)
    if s:is_vimconsole_window(bufnr)
      execute winnr . "wincmd w"

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

    endif
  endfor
  execute curr_winnr . "wincmd w"
endfunction " }}}

function! vimconsole#winopen(...) " {{{
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

    if g:vimconsole#plain_mode
      setlocal foldmethod=manual
    else
      setlocal foldmethod=expr
      setlocal foldtext=vimconsole#foldtext()
      setlocal foldexpr=(getline(v:lnum)[2]==#'\|')?'=':'>1'
    endif

    call vimconsole#define_plug_keymappings()
    call vimconsole#define_default_keymappings()
    call vimconsole#define_syntax()
    call vimconsole#define_highlight()

    call vimconsole#redraw()

    normal zm
  finally
    let &splitbelow = tmp
  endtry
  execute curr_winnr . "wincmd w"
endfunction " }}}

"  vim: set ts=2 sts=2 sw=2 ft=vim fdm=marker ff=unix :
