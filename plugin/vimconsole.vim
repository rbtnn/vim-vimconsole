
scriptencoding utf-8

if exists("g:loaded_vimconsole")
  finish
endif
let g:loaded_vimconsole = 1

let s:save_cpo = &cpo
set cpo&vim

let g:vimconsole#startinsert = get(g:, 'vimconsole#startinsert', 0)
let g:vimconsole#auto_redraw = get(g:,'vimconsole#auto_redraw',0)
let g:vimconsole#enable_quoted_string = get(g:,'vimconsole#enable_quoted_string', 1)
let g:vimconsole#eval_function_name = get(g:,'vimconsole#eval_function_name','eval')
let g:vimconsole#height = get(g:,'vimconsole#height', '&lines / 2')
let g:vimconsole#hooks = get(g:,'vimconsole#hooks',{})
let g:vimconsole#maximum_caching_objects_count = get(g:,'vimconsole#maximum_caching_objects_count', 100)
let g:vimconsole#no_default_key_mappings = get(g:,'vimconsole#no_default_key_mappings', 0)
let g:vimconsole#session_type = get(g:,'vimconsole#session_type', 't:')
let g:vimconsole#split_rule = get(g:,'vimconsole#split_rule', 'bottom')
let g:vimconsole#width = get(g:,'vimconsole#width', '&columns / 2')

call vimconsole#define_commands()

let &cpo = s:save_cpo
finish

