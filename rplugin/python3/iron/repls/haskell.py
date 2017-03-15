# encoding:utf-8
"""Haskell repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

ghci = {
    'command': 'ghci',
    'language': 'haskell',
    'detect': detect_fn('ghci'),
}

stackghci = {
    'command': 'stack ghci',
    'language': 'haskell',
    'detect': detect_fn('stack'),
}
