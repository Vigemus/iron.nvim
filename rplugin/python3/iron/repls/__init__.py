# encoding:utf-8
"""General repl definitions for iron.nvim. """
import iron.repls.lein
import iron.repls.python
import iron.repls.scala
import iron.repls.lua

available_repls = [
    lein.repl,
    python.python,
    python.ipython,
    lua.repl,
    scala.sbt,
    scala.sbt_,
    scala.scala,
]
