# encoding:utf-8
"""Leiningen repl definition for iron.nvim. """

def lein_require(nvim):
    nvim.command("""normal! "sya]""")
    data = "(require '{})\n".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSendToRepl', data, "clojure")

def lein_import(nvim):
    nvim.command("""normal! "syi(""")
    data = "(import '[{}])\n".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSendToRepl', data, "clojure")

def lein_require_file(nvim):
    nvim.command("""normal! ggf w"sy$""")
    data = "(require '[{}] :reload)\n".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSendToRepl', data, "clojure")

def lein_send(nvim):
    nvim.command("""normal! "sya(""")
    data = "(import '[{}])\n".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSendToRepl', data, "clojure")

repl = {
    'command': 'lein repl',
    'language': 'clojure',
    'mappings': [
        ('<leader>so', lein_require),
        ('<leader>si', lein_import),
        ('<leader>sr', lein_require_file),
        ('<leader>ss', lein_send),
    ]
}
