# encoding:utf-8
"""General repl definitions for iron.nvim. """
import iron.repls.clojure
import iron.repls.elixir
import iron.repls.elm
import iron.repls.erlang
import iron.repls.haskell
import iron.repls.julia
import iron.repls.lisp
import iron.repls.lua
import iron.repls.node
import iron.repls.ts_node
import iron.repls.ocaml
import iron.repls.php
import iron.repls.pure
import iron.repls.python
import iron.repls.r
import iron.repls.racket
import iron.repls.ruby
import iron.repls.scala
import iron.repls.scheme
import iron.repls.sh
import iron.repls.tcl

available_repls = [
    clojure.connect,
    clojure.boot,
    clojure.repl,
    elm.repl,
    elixir.repl,
    erlang.repl,
    haskell.intero,
    haskell.stackghci,
    haskell.ghci,
    julia.repl,
    lua.repl,
    lisp.sbcl,
    lisp.clisp,
    ocaml.utop,
    ocaml.ocamltop,
    php.psyshell,
    php.php,
    python.ptipython,
    python.ipython,
    python.ptpython,
    python.python,
    pure.repl,
    node.repl,
    ts_node.repl,
    ruby.repl,
    scala.sbt_cmd,
    scala.sbt_file,
    scala.scala,
    scheme.guile,
    scheme.chicken,
    r.repl,
    racket.repl,
    tcl.repl,
    sh.zsh_zsh,
    sh.zsh_sh,
    sh.bash_sh,
    sh.sh_sh
]
