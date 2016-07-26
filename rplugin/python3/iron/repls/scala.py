# encoding:utf-8
"""Scala repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

def scala_import_all(iron):
    iron.call_cmd("""normal! gg f w"sy$""")
    data = "import {}._".format(iron.register('s'))
    return iron.send_to_repl((data, "scala"))

def scala_import(iron):
    iron.call_cmd("""normal! gg f w"sy$""")
    data = "import {}".format(iron.register('s'))
    return iron.send_to_repl((data, "scala"))

def scala_send_block(iron):
    iron.call_cmd("""normal! Vi{"sy""")
    data = "{}".format(iron.register('s'))
    return iron.send_to_repl((data, "scala"))

def scala_send_line(iron):
    iron.call_cmd("""normal! 0"sy$""")
    data = "{}".format(iron.register('s'))
    return iron.send_to_repl((data, "scala"))


mappings = [
    ('<leader>sa', 'import_all', scala_import_all),
    ('<leader>si', 'import', scala_import),
    ('<leader>sb', 'block', scala_send_block),
    ('<leader>sl', 'line', scala_send_line),
]

sbt_file = {
    'command': 'sbt',
    'language': 'sbt.scala',
    'detect': detect_fn('sbt'),
    'mappings': mappings,
    'multiline': (':paste', '\x04'),
}

sbt_cmd = {
    'command': 'sbt',
    'language': 'scala',
    'detect': detect_fn('sbt', ['build.sbt', 'project/build.sbt']),
    'mappings': mappings,
    'multiline': (':paste', '\x04'),
}


scala = {
    'command': 'scala',
    'language': 'scala',
    'detect': detect_fn('scala'),
    'mappings': mappings,
    'multiline': (':paste', '\x04'),
}
