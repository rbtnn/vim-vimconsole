
# vimconsole.vim

This is immediate-window for Vim script.  
It is like Google Chrome Developer Console.  

![](https://github.com/rbtnn/vimconsole.vim/raw/dev/vimconsole.png)

## How to use

* vimconsole#log(obj)

It is like javascript's `console.log({obj})`.

* vimconsole#error(msg)

It is like javascript's `console.error({msg})`.

* :VimConsoleOpen

Open VimConsole. (same as `vimconsole#winopen()`)

* :VimConsoleClose

Close VimConsole. (same as `vimconsole#winclose()`)

* :VimConsoleClear

Clear logs of VimConsole. (same as `vimconsole#clear()`)

* :VimConsoleRedraw

Redraw VimConsole. (same as `vimconsole#redraw()`)

