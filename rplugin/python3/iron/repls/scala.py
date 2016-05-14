# encoding:utf-8
"""Scala repl definitions for iron.nvim. """

def sbt_detect(*args, **kwargs):
    import os
    return os.path.exists("build.sbt") or os.path.exists("project/build.sbt")


def scala_import_all(nvim):
    nvim.command("""normal! gg f w"sy$""")
    data = "import {}._".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSend', data, "scala")

def scala_import(nvim):
    nvim.command("""normal! gg f w"sy$""")
    data = "import {}".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSend', data, "scala")

def scala_send_block(nvim):
    nvim.command("""normal! Vi{"sy""")
    data = "{}".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSend', data, "scala")

def scala_send_line(nvim):
    nvim.command("""normal! 0"sy$""")
    data = "{}".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSend', data, "scala")


mappings = [
    ('<leader>sa', 'import_all', scala_import_all),
    ('<leader>si', 'import', scala_import),
    ('<leader>sb', 'block', scala_send_block),
    ('<leader>sl', 'line', scala_send_line),
]

sbt = {
    'command': 'sbt console',
    'language': 'scala',
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
