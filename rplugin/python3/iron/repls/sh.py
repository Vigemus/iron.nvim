# encoding:utf-8
"""Shell 'repl' definition for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

def prompt_cmd(iron):
    try:
        cmd = iron.prompt("command")
    except:
        iron.call_cmd("echo 'Aborting'")
    else:
        return iron.send_to_repl((cmd, "sh"))

global_mappings = [
    ('<leader>sx', 'prompt_cmd', prompt_cmd),
]

zsh_sh = {
    'command': 'zsh',
    'language': 'sh',
    'detect': detect_fn('zsh'),
    'global_mappings': global_mappings,
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
    'global_mappings': global_mappings,
}

sh_sh = {
    'command': 'sh',
    'language': 'sh',
    'detect': detect_fn('sh'),
    'global_mappings': global_mappings,
}
