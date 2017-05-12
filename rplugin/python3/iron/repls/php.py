# encoding:utf-8
"""PHP repl definition for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

php = {
    'command': 'php -a',
    'language': 'php',
    'detect': detect_fn('php'),
}

psyshell = {
    'command': 'psysh',
    'language': 'php',
    'detect': detect_fn('psysh'),
}
