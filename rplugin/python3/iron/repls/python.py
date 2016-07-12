# encoding:utf-8
"""Python repl definitions for iron.nvim. """


def set_pdb(nvim):
    pass


def detect_python_repl(repl):
    """Checks whether a executable exists.
    :returns: True
    """
    from distutils.spawn import find_executable
    return find_executable(repl) is not None

python = {
    'command': 'python',
    'language': 'python',
    'detect': lambda *args, **kwargs: detect_python_repl('python'),
}

ipython = {
    'command':   'ipython',
    'language':  'python',
    'multiline': ('%cpaste', '--'),
    'detect': lambda *args, **kwargs: detect_python_repl('ipython'),
}


ptpython = {
    'command': 'ptpython',
    'language': 'python',
    'multiline': ('\x1b[200~', '\x1b[201~'),
    'detect': lambda *args, **kwargs: detect_python_repl('ptpython'),
}


ptipython = {
   'command': 'ptipython',
    'language': 'python',
    'multiline': ('\x1b[200~', '\x1b[201~'),
    'detect': lambda *args, **kwargs: detect_python_repl('ptipython'),
}
