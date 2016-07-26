# encoding:utf-8
"""R repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

repl = {
    'command': 'R',
    'language': 'r',
    'detect': detect_fn('R')
}
