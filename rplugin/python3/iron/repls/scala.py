# encoding:utf-8
"""Scala repl definitions for iron.nvim. """
from iron.repls.utils.cmd import detect_fn

def get_ns(iron):
    iron.call_cmd("""normal! mxgg f w"sy$`x""")
    return iron.register('s')

def get_class(iron):
    # fcflfa -> Make sure we get to class even if
    # protected sealed class or protected final class
    iron.call_cmd("""global/class/normal! 0fcflfab"syt """)
    return iron.register('s')

def get_object(iron):
    iron.call_cmd("""global/object/normal! 0fbb"syt """)
    return iron.register('s')

def scala_import_all_ns(iron):
    data = "import {}._".format(get_ns(iron))
    return iron.send_to_repl((data, "scala"))

def scala_import_all_object(iron):
    data = "import {}.{}._".format(get_ns(iron), get_object(iron))
    return iron.send_to_repl((data, "scala"))

def scala_import(iron):
    data = "import {}".format(get_ns(ion))
    return iron.send_to_repl((data, "scala"))

def scala_send_block(iron):
    iron.call_cmd("""normal! Vi{"sy""")
    data = "{}".format(iron.register('s'))
    return iron.send_to_repl((data, "scala"))

def scala_send_line(iron):
    iron.call_cmd("""normal! 0"sy$""")
    data = "{}".format(iron.register('s'))
    return iron.send_to_repl((data, "scala"))

def sbt_test_this_file(iron):
    data = "test {}.{}".format(get_ns(iron), get_class(iron))
    return iron.send_to_repl((data, "sbt.scala"))


mappings = [
    ('<leader>sa', 'import_all', scala_import_all_ns),
    ('<leader>si', 'import', scala_import),
    ('<leader>sb', 'block', scala_send_block),
    ('<leader>sl', 'line', scala_send_line),
]

sbt_file = {
    'command': 'sbt',
    'language': 'sbt.scala',
    'mappings': mappings,
    'multiline': (':paste\n', '\x04'),
}

sbt_cmd = {
    'command': 'sbt',
    'language': 'scala',
    'detect': detect_fn('sbt', ['build.sbt', 'project/build.sbt']),
    'mappings': mappings,
    'multiline': (':paste\n', '\x04'),
}

scala = {
    'command': 'scala',
    'language': 'scala',
    'mappings': mappings,
    'multiline': (':paste\n', '\x04'),
}

def do_stuff():
    nvim.command("2 wincmd w")
    nvim.command("""global/get_ns/normal! 0f "Gyt(""")
    return nvim.funcs.getreg("g")
