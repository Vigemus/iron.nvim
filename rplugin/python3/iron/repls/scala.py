# encoding:utf-8
"""Scala repl definitions for iron.nvim. """

def sbt_detect(*args, **kwargs):
    import os
    return os.path.exists("build.sbt") or os.path.exists("project/build.sbt")

sbt = {
    'command': 'sbt console',
    'language': 'scala',
    'detect': sbt_detect,
}

scala = {
    'command': 'scala',
    'language': 'scala',
    'detect': lambda *args, **kwargs: not sbt_detect(*args, **kwargs),
}
