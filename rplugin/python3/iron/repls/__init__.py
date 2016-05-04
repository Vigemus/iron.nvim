# encoding:utf-8
"""General repl definitions for iron.nvim. """
import iron.repls.lein
import iron.repls.ipython

available_repls = [
    lein.repl,
    ipython.repl
]
