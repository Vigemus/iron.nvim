# encoding:utf-8
"""General repl definitions for iron.nvim. """
import iron.repls.clojure
import iron.repls.python
import iron.repls.scala
import iron.repls.lua

available_repls = [
    clojure.repl,
    python.python,
    python.ipython,
    lua.repl,
    scala.sbt_file,
    scala.sbt_cmd,
    scala.scala,
]
