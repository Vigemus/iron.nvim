# encoding:utf-8
"""SBCL repl definition for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

repl = {
    'command': 'sbcl',
    'language': 'lisp',
    'detect': detect_fn('sbcl'),
}
