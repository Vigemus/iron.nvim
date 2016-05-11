# encoding:utf-8
"""Leiningen repl definition for iron.nvim. """

def lein_require(nvim):
    nvim.command("""normal! "sya]""")
    data = "(require '{})\n".format(nvim.funcs.getreg('s'))
    return nvim.call('jobsend', repl['repl_id'], data)

def lein_import(nvim):
    nvim.command("""normal! "syi(""")
    data = "(import '[{}])\n".format(nvim.funcs.getreg('s'))
    return nvim.call('jobsend', repl['repl_id'], data)

def lein_require_file(nvim):
    nvim.command("""normal! ggf w"sy$""")
    data = "(require '[{}] :reload)\n".format(nvim.funcs.getreg('s'))
    return nvim.call('jobsend', repl['repl_id'], data)

def lein_send(nvim):
    nvim.command("""normal! "sya(""")
    data = "(import '[{}])\n".format(nvim.funcs.getreg('s'))
    return nvim.call('jobsend', repl['repl_id'], data)

repl = {
    'command': 'lein repl',
    'language': 'clojure',
    'mappings': [
        ('so', lein_require),
        ('si', lein_import),
        ('sr', lein_require_file),
        ('ss', lein_send),
    ]
}
