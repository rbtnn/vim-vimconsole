
scriptencoding utf-8

if exists("g:loaded_vimconsole")
  finish
endif
let g:loaded_vimconsole = 1

let s:save_cpo = &cpo
set cpo&vim

let g:vimconsole#height = get(g:,'vimconsole#height',6)
let g:vimconsole#width = get(g:,'vimconsole#width', 40)

let g:vimconsole#eval_function_name = get(g:,'vimconsole#eval_function_name','eval')

let g:vimconsole#auto_redraw = get(g:,'vimconsole#auto_redraw',0)
let g:vimconsole#hooks = get(g:,'vimconsole#hooks',{})
let g:vimconsole#maximum_caching_objects_count = get(g:,'vimconsole#maximum_caching_objects_count', 20)
let g:vimconsole#plain_mode = get(g:,'vimconsole#plain_mode', 0)
let g:vimconsole#split_rule = get(g:,'vimconsole#split_rule', 'bottom')
let g:vimconsole#dump_path = get(g:,'vimconsole#dump_path', expand('~/vimconsole.dump'))
let g:vimconsole#enable_quoted_string = get(g:,'vimconsole#enable_quoted_string', 1)
let g:vimconsole#no_default_key_mappings = get(g:,'vimconsole#no_default_key_mappings', 0)
let g:vimconsole#session_type = get(g:,'vimconsole#session_type', 't:')

let g:vimconsole#highlight_default_link_groups = get(g:,'vimconsole#highlight_default_link_groups',{})

let g:vimconsole#command_complete = get(g:,'vimconsole#command_complete', 'expression')

call vimconsole#define_commands()

let &cpo = s:save_cpo
finish

