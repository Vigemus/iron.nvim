local clojure = {}

clojure.boot = {
  command = {"boot", "repl"},
}

clojure.lein = {
  command = {"lein", "repl"},
}

clojure.clj = {
  command = {"clj"},
}

return clojure
