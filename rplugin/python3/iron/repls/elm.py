# encoding:utf-8
"""Elm repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

repl = {
    'command': 'elm-repl',
    'language': 'elm',
    'detect': detect_fn('elm-repl')
}
