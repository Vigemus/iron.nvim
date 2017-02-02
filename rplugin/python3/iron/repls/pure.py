# encoding:utf-8
"""Pure-lang repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

def pure_send_block(iron):
    iron.call_cmd("""normal! Vi{"sy""")
    data = "{}".format(iron.register('s'))
    return iron.send_to_repl((data, "pure"))

def pure_send_line(iron):
    iron.call_cmd("""normal! 0"sy$""")
    data = "{}".format(iron.register('s'))
    return iron.send_to_repl((data, "pure"))

mappings = [
    ('<leader>sb', 'block', pure_send_block),
    ('<leader>sl', 'line', pure_send_line),
]

repl = {
    'command': 'pure',
    'language': 'pure',
    'detect': detect_fn('pure'),
    'mappings': mappings,
    'multiline': (':paste\n', '\x04'),
}
