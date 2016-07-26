# encoding:utf-8
"""Erlang repl definition for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

repl = {
    'command': 'erl',
    'language': 'erlang',
    'detect': detect_fn('erl'),
}
