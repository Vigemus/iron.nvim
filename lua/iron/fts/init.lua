-- luacheck: globals unpack

local fts = {
  clojure = require("iron.fts.clojure"),
  elixir = require("iron.fts.elixir"),
  elm = require("iron.fts.elm"),
  erlang = require("iron.fts.erlang"),
  haskell = require("iron.fts.haskell"),
  javascript = require("iron.fts.javascript"),
  julia = require("iron.fts.julia"),
  lisp = require("iron.fts.lisp"),
  lua = require("iron.fts.lua"),
  ocaml = require("iron.fts.ocaml"),
  php = require("iron.fts.php"),
  pure = require("iron.fts.pure"),
  python = require("iron.fts.python"),
  r = require("iron.fts.r"),
  racket = require("iron.fts.racket"),
  ruby = require("iron.fts.ruby"),
  sbt_scala = require("iron.fts.sbt"),
  scala = require("iron.fts.scala"),
  scheme = require("iron.fts.scheme"),
  sh = require("iron.fts.sh"),
  tcl = require("iron.fts.tcl"),
  typescript = require("iron.fts.typescript"),
  zsh = require("iron.fts.zsh")
}

return fts
