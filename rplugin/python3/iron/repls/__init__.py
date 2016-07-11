# encoding:utf-8
"""General repl definitions for iron.nvim. """
import iron.repls.clojure
import iron.repls.elixir
import iron.repls.erlang
import iron.repls.lua
import iron.repls.python
import iron.repls.node
import iron.repls.ruby
import iron.repls.scala
import iron.repls.r

available_repls = [
    clojure.repl,
    elixir.repl,
    erlang.repl,
    lua.repl,
    python.ptipython,
    python.ipython,
    python.ptpython,
    python.python,
    node.repl,
    ruby.repl,
    scala.sbt_cmd,
    scala.sbt_file,
    scala.scala,
    r.repl,
]
