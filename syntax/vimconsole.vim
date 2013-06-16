
if exists ("b:current_syntax")
  finish
endif

syn match   vimconsoleTitle    '^--.*$'
syn match   vimconsoleID    '^..\(-\||\)' containedin=ALL
syn match   vimconsoleNumber      /^ 0\(-\||\).*$/
syn match   vimconsoleString      /^ 1\(-\||\).*$/
syn match   vimconsoleFuncref     /^ 2\(-\||\).*$/
syn match   vimconsoleList        /^ 3\(-\||\).*$/
syn match   vimconsoleDictionary  /^ 4\(-\||\).*$/
syn match   vimconsoleFloat       /^ 5\(-\||\).*$/
syn match   vimconsoleError       /^ 6\(-\||\).*$/
syn match   vimconsoleWarning     /^ 7\(-\||\).*$/

hi def link vimconsoleTitle      Title
hi def link vimconsoleID         Ignore
hi def link vimconsoleNumber     Normal
hi def link vimconsoleString     Normal
hi def link vimconsoleFuncref    Normal
hi def link vimconsoleList       Normal
hi def link vimconsoleDictionary Normal
hi def link vimconsoleFloat      Normal
hi def link vimconsoleFloat      Normal
hi def link vimconsoleError      Error
hi def link vimconsoleWarning    WarningMsg


let b:current_syntax = "vimconsole"

