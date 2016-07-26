# encoding:utf-8
"""Elixir repl definition for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

repl = {
    'command': 'iex',
    'language': 'elixir',
    'detect': detect_fn('iex'),
}
