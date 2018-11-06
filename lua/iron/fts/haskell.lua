local haskell = {}

haskell.stack_intero = {
  command = {"stack", "ghci", "--with-ghc", "intero"},
}

haskell.stack = {
  command = {"stack", "ghci"},
}

haskell.ghci = {
  command = {"ghci"},
}

return haskell
