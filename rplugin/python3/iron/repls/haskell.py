# encoding:utf-8
"""Haskell repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

ghci = {
    'command': 'ghci',
    'language': 'haskell',
}

stackghci = {
    'command': 'stack ghci',
    'language': 'haskell',
}

intero = {
    'command': 'stack ghci --with-ghc intero',
    'language': 'haskell',
    'detect': detect_fn('intero'),
}
