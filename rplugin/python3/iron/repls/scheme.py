# encoding:utf-8
"""Scheme repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

guile = {
    'command': 'guile',
    'language': 'scheme',
    'detect': detect_fn('guile')
}

chicken = {
    'command': 'csi',
    'language': 'scheme',
    'detect': detect_fn('csi')
}
