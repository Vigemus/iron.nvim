# encoding:utf-8
"""General repl definitions for iron.nvim. """
import iron.repls.clojure
import iron.repls.elm
import iron.repls.elixir
import iron.repls.erlang
import iron.repls.lua
import iron.repls.lisp
import iron.repls.ocaml
import iron.repls.python
import iron.repls.pure
import iron.repls.node
import iron.repls.ruby
import iron.repls.scala
import iron.repls.scheme
import iron.repls.sh
import iron.repls.r
import iron.repls.tcl

available_repls = [
    clojure.connect,
    clojure.boot,
    clojure.repl,
    elm.repl,
    elixir.repl,
    erlang.repl,
    lua.repl,
    lisp.sbcl,
    lisp.clisp,
    ocaml.utop,
    ocaml.ocamltop,
    python.ptipython,
    python.ipython,
    python.ptpython,
    python.python,
    pure.repl,
    node.repl,
    ruby.repl,
    scala.sbt_cmd,
    scala.sbt_file,
    scala.scala,
    scheme.repl,
    r.repl,
    tcl.repl,
    sh.zsh_zsh,
    sh.zsh_sh,
    sh.bash_sh,
    sh.sh_sh
]
