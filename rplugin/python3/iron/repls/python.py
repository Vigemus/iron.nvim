# encoding:utf-8
"""Python repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn


def set_pdb(iron):
    iron.send_to_repl("pdb")



mappings = [
    ('<leader>pp', 'set_pdb', set_pdb),
]


python = {
    'command': 'python',
    'language': 'python',
    'detect': detect_fn('python'),
}

ipython = {
    'command':   'ipython',
    'language':  'python',
    'multiline': ('\x1b[200~', '\x1b[201~', '\r'),
    'detect': detect_fn('ipython'),
}


ptpython = {
    'command': 'ptpython',
    'language': 'python',
    'multiline': ('\x1b[200~', '\x1b[201~', '\r'),
    'detect': detect_fn('ptpython'),
}


ptipython = {
    'command': 'ptipython',
    'language': 'python',
    'multiline': ('\x1b[200~', '\x1b[201~', '\r'),
    'detect': detect_fn('ptipython') and detect_fn('ipython'),
}
