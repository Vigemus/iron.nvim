# encoding:utf-8
"""Node repl definition for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

repl = {
    'command': 'node',
    'language': 'javascript',
    'detect': detect_fn('node')
}
