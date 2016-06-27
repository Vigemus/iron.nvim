# encoding:utf-8
"""General repl definitions for iron.nvim. """
import iron.repls.lein
import iron.repls.python
import iron.repls.scala
import iron.repls.sbt
import iron.repls.lua

available_repls = [
    lein.repl,
    python.python,
    python.ipython,
    lua.repl,
    sbt.sbt,
    scala.sbt,
    scala.scala,
]
