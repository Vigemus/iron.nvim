# encoding:utf-8
"""Pure-lang repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

repl = {
    'command': 'pure',
    'language': 'pure',
    'detect': detect_fn('pure')
}
