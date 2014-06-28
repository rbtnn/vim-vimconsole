
scriptencoding utf-8

function! s:buf_nr(bname)
  return bufnr(s:buf_escape(a:bname))
endfunction
function! s:buf_escape(bname)
  return '^' . join(map(split(a:bname, '\zs'), '"[".v:val."]"'), '') . '$'
endfunction
function! s:buf_winnr(bname)
  return bufwinnr(s:buf_escape(a:bname))
endfunction

function! s:receive_vimproc_result(key)
  let session = vimconsole#async#session(a:key).session
  let vimproc = session._vimproc

  try
    if !vimproc.stdout.eof
      call session.outputter(vimproc.stdout.read(), 'stdout')
    endif
    if !vimproc.stderr.eof
      call session.outputter(vimproc.stderr.read(), 'stderr')
    endif

    if !(vimproc.stdout.eof && vimproc.stderr.eof)
      call feedkeys(mode() ==# 'i' ? "\<C-g>\<ESC>" : "g\<ESC>", 'n')
      return 0
    endif
  catch
    " XXX: How is an internal error displayed?
    call session.outputter(('async vimproc: ' . v:throwpoint . "\n" . v:exception), '_')
  endtry

  call vimproc.stdout.close()
  call vimproc.stderr.close()
  call vimproc.waitpid()
  call session.finish(get(vimproc, 'status', 1))
  call session.sweep(get(vimproc, 'status', 1))
  return 1
endfunction
function! s:async_system(commands, ...)
  let session = get(a:000, 0, {})

  let session.input = get(session,'input', '')
  let session.key = get(session,'key', 'A')
  let session.runner_id = get(session,'runner_id', 'plugin-async-runner-vimproc')
  let session.config = get(session,'config',{})
  let session.config.updatetime = get(session.config,'updatetime',0)
  let session.config.sleep = get(session.config,'sleep',50)

  call vimconsole#async#session(session.key,session)

  " Create augroup.
  execute 'augroup ' . session.runner_id
augroup END

let vimproc = vimproc#pgroup_open(join(a:commands, ' && '))
call vimproc.stdin.write(session.input)
call vimproc.stdin.close()

let session._vimproc = vimproc

if ! has_key(session,'outputter')
  let session['outputter'] = function('vimconsole#async#default_outputter')
endif

if ! has_key(session,'finish')
  function! session.finish(vimproc_status)
  endfunction
endif

function! session.sweep(vimproc_status)
  if has_key(self, '_autocmd')
    execute 'autocmd! ' . self.runner_id
  endif
  if has_key(self, '_updatetime')
    let &updatetime = self._updatetime
  endif
endfunction

" Wait a little because execution might end immediately.
if session.config.sleep
  execute 'sleep' session.config.sleep . 'm'
endif

if s:receive_vimproc_result(session.key)
  return
endif

" Execution is continuing.
execute 'augroup ' . session.runner_id
execute 'autocmd! CursorHold,CursorHoldI * call s:receive_vimproc_result(' . string(session.key) . ')'
augroup END

let session._autocmd = 1
if session.config.updatetime
  let session._updatetime = &updatetime
  let &updatetime = session.config.updatetime
endif
endfunction

function! vimconsole#async#default_outputter(...)
  let data = get(a:000, 0, '')
  let type = get(a:000, 1, '')
  if type is 'stdout'
    call vimconsole#log(data)
  elseif type is 'stderr'
    call vimconsole#error(data)
  endif
endfunction
function! vimconsole#async#winopen(...)
  let lines = get(a:000, 0, [])
  let mode = get(a:000, 1, 'a')
  let bname = get(a:000, 2, '[async]')

  let curr_bufname = bufname('%')

  if ! bufexists(bname)
    execute printf('split %s', bname)
    setlocal bufhidden=hide buftype=nofile noswapfile nobuflisted
  elseif s:buf_winnr(bname) isnot -1
    execute s:buf_winnr(bname) 'wincmd w'
  else
    execute 'split'
    execute 'buffer' s:buf_nr(bname)
  endif

  if mode is# 'w'
    silent % delete _
    silent put=vimconsole#enc#iconv(lines)
    silent 1 delete _
  elseif mode is# 'a'
    call append('$', vimconsole#enc#iconv(lines))
  endif

  execute s:buf_winnr(curr_bufname) 'wincmd w'
endfunction
function! vimconsole#async#session(key,...)
  let s:async_sessions = get(s:,'async_sessions',{})
  if 0 < a:0
    let s:async_sessions[ a:key ] = a:1
  else
    let s:async_sessions[ a:key ] = get(s:async_sessions,a:key,{})
  endif
  return { 'key' : a:key, 'session' : s:async_sessions[ a:key ] }
endfunction
function! vimconsole#async#system(input_str)
  if -1 isnot match(a:input_str, '^\s*pwd\s*$')
    return getcwd()
  elseif -1 isnot match(a:input_str, '^\s*l\?cd .*$')
    let str = matchstr(a:input_str, '^\s*l\?cd .*$')
    silent execute str
    return getcwd()
  elseif -1 isnot match(a:input_str, '^\s*vim\s*$')
    if winnr('$') is 1
      new
    endif
    call vimconsole#winclose()
    enew
    call vimconsole#winopen()
  elseif -1 isnot match(a:input_str, '^\s*vim .*$')
    if winnr('$') is 1
      new
    endif
    let path = matchstr(a:input_str, '^\s*vim \zs.*$')
    if filereadable(expand(path))
      call vimconsole#winclose()
      silent execute printf('edit %s', path)
      call vimconsole#winopen()
    endif
  else
    try
      call vimproc#version()
    catch '.*'
    endtry
    if exists('g:loaded_vimproc')
      call s:async_system([(a:input_str)], { 'outputter' : function('vimconsole#async#default_outputter') })
    else
      return system(a:input_str)
    endif
  endif
  return ''
endfunction
