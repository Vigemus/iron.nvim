# encoding:utf-8
"""Shell 'repl' definition for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

zsh_sh = {
    'command': 'zsh',
    'language': 'sh',
    'detect': detect_fn('zsh'),
}

zsh_zsh = {
    'command': 'zsh',
    'language': 'zsh',
    'detect': detect_fn('zsh'),
}

bash_sh = {
    'command': 'bash',
    'language': 'sh',
    'detect': detect_fn('bash'),
}

sh_sh = {
    'command': 'sh',
    'language': 'sh',
    'detect': detect_fn('sh'),
}
