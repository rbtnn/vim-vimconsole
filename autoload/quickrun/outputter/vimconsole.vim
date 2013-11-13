
let s:save_cpo = &cpo
set cpo&vim

let s:outputter = {
\   'config': {
\     'height': g:vimconsole#height,
\     'width': g:vimconsole#width,
\     'split_rule': g:vimconsole#split_rule,
\     'enable_quoted_string': g:vimconsole#enable_quoted_string,
\     'maximum_caching_objects_count': g:vimconsole#maximum_caching_objects_count,
\   }
\ }

let s:caches = {}

function! s:outputter.init(session)
  let s:caches['height'] = g:vimconsole#height
  let s:caches['width'] = g:vimconsole#width
  let s:caches['split_rule'] = g:vimconsole#split_rule
  let s:caches['enable_quoted_string'] = g:vimconsole#enable_quoted_string
  let s:caches['maximum_caching_objects_count'] = g:vimconsole#maximum_caching_objects_count
endfunction

function! s:outputter.start(session)
endfunction

function! s:outputter.output(data, session)
  call vimconsole#log(a:data)
endfunction

function! s:outputter.sweep()
  let g:vimconsole#height = s:caches['height']
  let g:vimconsole#width = s:caches['width']
  let g:vimconsole#split_rule = s:caches['split_rule']
  let g:vimconsole#enable_quoted_string = s:caches['enable_quoted_string']
  let g:vimconsole#maximum_caching_objects_count = s:caches['maximum_caching_objects_count']
endfunction

function! s:outputter.finish(session)
  let g:vimconsole#height = self.config.height
  let g:vimconsole#width = self.config.width
  let g:vimconsole#split_rule = self.config.split_rule
  let g:vimconsole#enable_quoted_string = self.config.enable_quoted_string
  let g:vimconsole#maximum_caching_objects_count = self.config.maximum_caching_objects_count

  call vimconsole#winopen('!')
endfunction

function! quickrun#outputter#vimconsole#new()
  return deepcopy(s:outputter)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
