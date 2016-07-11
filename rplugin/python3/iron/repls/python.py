# encoding:utf-8
"""Python repl definitions for iron.nvim. """


def set_pdb(nvim):
    pass


def detect_python_repl(*args, **kwargs):
    """Detects python repls in this order:
    - ptipython
    - ipython
    - ptpython
    - python

    :returns: True

    """
    from distutils.spawn import find_executable
    if find_executable("ptipython") is not None:
        return 'ptipython'
    elif find_executable("ipython") is not None:
        return 'ipython'
    elif find_executable("ptpython") is not None:
        return 'ptpython'
    else:
        return 'python'


python = {
    'command': 'python',
    'language': 'python',
    'detect': lambda *args, **kwargs: detect_python_repl(*args, **kwargs) == 'python',
}

ipython = {
    'command':   'ipython',
    'language':  'python',
    'multiline': ('%cpaste', '--'),
    'detect': lambda *args, **kwargs: detect_python_repl(*args, **kwargs) == 'ipython',
}


ptpython = {
    'command': 'ptpython',
    'language': 'python',
    'multiline': ('%cpaste', '--'),
    'detect': lambda *args, **kwargs: detect_python_repl(*args, **kwargs) == 'ptpython',
}


ptipython = {
    'command': 'ptipython',
    'language': 'python',
    'multiline': ('%cpaste', '--'),
    'detect': lambda *args, **kwargs: detect_python_repl(*args, **kwargs) == 'ptipython',
}
