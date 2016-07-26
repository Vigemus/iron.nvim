# encoding:utf-8
"""Ruby repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

repl = {
    'command': 'irb',
    'language': 'ruby',
    'detect': detect_fn('irb')
}
