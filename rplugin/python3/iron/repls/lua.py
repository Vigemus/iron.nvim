# encoding:utf-8
"""Lua repl definition for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

repl = {
    'command': 'lua',
    'language': 'lua',
    'detect': detect_fn('lua')
}
