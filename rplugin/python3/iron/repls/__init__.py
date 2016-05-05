# encoding:utf-8
"""General repl definitions for iron.nvim. """
import iron.repls.lein
import iron.repls.ipython
import iron.repls.python
import iron.repls.lua

available_repls = [
    lein.repl,
    ipython.repl,
    python.repl,
    lua.repl,
]
