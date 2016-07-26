# encoding:utf-8
"""OCaml repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

ocamltop = {
    'command': 'ocamltop',
    'language': 'ocaml',
    'detect': detect_fn('ocamltop')
}

utop = {
    'command': 'utop',
    'language': 'ocaml',
    'detect': detect_fn('utop')
}
