# encoding:utf-8
"""Python repl definitions for iron.nvim. """

python = {
    'command': 'python',
    'language': 'python',
    'detect': lambda *args, **kwargs: True,
}

ipython = {
    'command': 'ipython',
    'language': 'python',
    'multiline': ('%cpaste', '--'),
}
