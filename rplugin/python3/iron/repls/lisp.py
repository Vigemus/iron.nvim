# encoding:utf-8
"""Lisp repl definition for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

sbcl = {
    'command': 'sbcl',
    'language': 'lisp',
    'detect': detect_fn('sbcl')
}

clisp = {
    'command': 'clisp',
    'language': 'lisp',
    'detect': detect_fn('clisp')
}
