# encoding:utf-8
"""Shell 'repl' definition for iron.nvim. """

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
    'global_mappings': global_mappings,
}

zsh_zsh = {
    'command': 'zsh',
    'language': 'zsh',
}

bash_sh = {
    'command': 'bash',
    'language': 'sh',
    'global_mappings': global_mappings,
}

sh_sh = {
    'command': 'sh',
    'language': 'sh',
    'global_mappings': global_mappings,
}
