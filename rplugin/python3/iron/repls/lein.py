# encoding:utf-8
"""Leiningen repl definition for iron.nvim. """

def send_object_to_repl(nvim):
    nvim.command("""normal! "sya]""")
    data = "(require '{})\n".format(nvim.funcs.getreg('s'))
    return nvim.call('jobsend', repl['repl_id'], data)

repl = {
    'command': 'lein repl',
    'language': 'clojure',
    'mappings': [
        ('so', send_object_to_repl),
    ]
}
