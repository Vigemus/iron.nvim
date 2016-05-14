# encoding:utf-8
"""Python repl definitions for iron.nvim. """

def detect_ipython(*args, **kwargs):
    from distutils.spawn import find_executable
    return find_executable("ipython") is not None

python = {
    'command': 'python',
    'language': 'python',
    'detect': lambda *args, **kwargs: not detect_ipython(*args, **kwargs),
}

ipython = {
    'command': 'ipython',
    'language': 'python',
    'multiline': ('%cpaste', '--'),
    'detect': detect_ipython,
}
