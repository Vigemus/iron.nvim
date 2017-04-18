# encoding:utf-8
"""Scheme repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

repl = {
    'command': 'racket',
    'language': 'racket',
    'detect': detect_fn('racket')
}
