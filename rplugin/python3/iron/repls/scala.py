# encoding:utf-8
"""Scala repl definitions for iron.nvim. """

def sbt_detect(*args, **kwargs):
    import os
    return os.path.exists("build.sbt") or os.path.exists("project/build.sbt")


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

sbt = {
    'command': 'sbt',
    'language': 'scala',
    'detect': sbt_detect,
    'mappings': mappings,
    'multiline': (':paste', '<C-D>'),
}

sbt_ = {
    'command': 'sbt',
    'language': 'sbt.scala',
    'detect': sbt_detect,
    'mappings': mappings,
    'multiline': (':paste', '<C-D>'),
}

scala = {
    'command': 'scala',
    'language': 'scala',
    'detect': lambda *args, **kwargs: not sbt_detect(*args, **kwargs),
    'mappings': mappings,
    'multiline': (':paste', '<C-D>'),
}
