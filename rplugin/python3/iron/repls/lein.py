# encoding:utf-8
"""Leiningen repl definition for iron.nvim. """

def lein_require(nvim):
    nvim.command("""normal! "sya]""")
    data = "(require '{})\n".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSend', data, "clojure")

def lein_import(nvim):
    nvim.command("""normal! "syi(""")
    data = "(import '[{}])\n".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSend', data, "clojure")

def lein_require_file(nvim):
    nvim.command("""normal! ggf w"sy$""")
    data = "(require '[{}] :reload)\n".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSend', data, "clojure")

def lein_send(nvim):
    nvim.command("""normal! "sya(""")
    data = "(import '[{}])\n".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSend', data, "clojure")

repl = {
    'command': 'lein repl',
    'language': 'clojure',
    'mappings': [
        ('<leader>so', 'require', lein_require),
        ('<leader>si', 'import', lein_import),
        ('<leader>sr', 'require_file', lein_require_file),
        ('<leader>ss', 'send', lein_send),
    ]
}
