
scriptencoding utf-8

function! s:receive_vimproc_result(key)
  let session = vimconsole#async#session(a:key).session
  let vimproc = session._vimproc

  try
    if !has_key(session, 'stop')
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
    endif
  catch
    call session.outputter(('async vimproc: ' . v:throwpoint . "\n" . v:exception), '_')
  endtry

  call vimproc.stdout.close()
  call vimproc.stderr.close()
  call vimproc.waitpid()
  call session.finalizer(get(vimproc, 'status', 1))
  call session.sweep(get(vimproc, 'status', 1))
  return 1
endfunction
function! s:async_system(commands, ...)
  let session = get(a:000, 0, {})

  let session.input = get(session,'input', '')
  let session.key = get(session,'key', fnamemodify(tempname(), ':t:r'))
  let session.runner_id = get(session,'runner_id', 'plugin-async-runner-vimproc-' . session.key)
  let session.config = get(session,'config',{})
  let session.config.updatetime = get(session.config,'updatetime',0)
  let session.config.sleep = get(session.config,'sleep',50)

  call vimconsole#async#session(session.key, session)

  execute 'augroup ' . session.runner_id
  execute 'augroup END'

  let vimproc = vimproc#pgroup_open(join(a:commands, ' && '))
  call vimproc.stdin.write(session.input)
  call vimproc.stdin.close()

  let session._vimproc = vimproc

  if ! has_key(session,'initializer')
    let session['initializer'] = function('vimconsole#async#default_initializer')
  endif

  if ! has_key(session,'outputter')
    let session['outputter'] = function('vimconsole#async#default_outputter')
  endif

  if ! has_key(session, 'finalizer')
    let session['finalizer'] = function('vimconsole#async#default_finalizer')
  endif

  function! session.sweep(vimproc_status)
    if has_key(self, '_autocmd')
      execute 'autocmd! ' . self.runner_id
    endif
    if has_key(self, '_updatetime')
      let &updatetime = self._updatetime
    endif
    execute 'augroup! ' . self.runner_id
  endfunction

  if session.config.sleep
    execute 'sleep' session.config.sleep . 'm'
  endif

  call session.initializer()
  if s:receive_vimproc_result(session.key)
    return
  endif

  execute 'augroup ' . session.runner_id
  execute '  autocmd! CursorHold,CursorHoldI * call s:receive_vimproc_result(' . string(session.key) . ')'
  execute 'augroup END'

  let session._autocmd = 1
  if session.config.updatetime
    let session._updatetime = &updatetime
    let &updatetime = session.config.updatetime
  endif
endfunction

function! vimconsole#async#default_outputter(...) dict
  let data = get(a:000, 0, '')
  let type = get(a:000, 1, '')
  if type is 'stdout'
    call vimconsole#log(join(vimconsole#enc#iconv(data), "\n"))
  elseif type is 'stderr'
    call vimconsole#log(join(vimconsole#enc#iconv(data), "\n"))
  endif
endfunction
function! vimconsole#async#default_finalizer(vimproc_status) dict
  call vimconsole#log(printf('[vimconsole] async session end: %s', self.key))
endfunction
function! vimconsole#async#default_initializer() dict
  call vimconsole#log(printf('[vimconsole] async session begin: %s', self.key))
endfunction

function! vimconsole#async#stop()
  let s:async_sessions = get(s:,'async_sessions',{})
  for key in keys(s:async_sessions)
    let session = vimconsole#async#session(key).session
    let session['stop'] = 1
  endfor
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
function! vimconsole#async#system(input_str, ...)
  try
    call vimproc#version()
    call s:async_system([(a:input_str)], {
          \   'initializer' : 0 < a:0 ? a:1 : function('vimconsole#async#default_initializer'),
          \   'outputter'   : 1 < a:0 ? a:2 : function('vimconsole#async#default_outputter'),
          \   'finalizer'   : 2 < a:0 ? a:3 : function('vimconsole#async#default_finalizer'),
          \ })
  catch '.*'
  endtry
  return ''
endfunction
function! vimconsole#async#system_with_vim(input_str, ...)
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
  elseif -1 isnot match(a:input_str, '^\s*:.*$')
    let cmd = matchstr(a:input_str, '^\s*:\zs.*$')
    redir => output
    silent! execute cmd
    redir END
    call vimconsole#log(output)
  else
    call vimconsole#async#system(a:input_str)
  endif
  return ''
endfunction

