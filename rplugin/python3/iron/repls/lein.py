# encoding:utf-8
"""Leiningen repl definition for iron.nvim. """


def lein_require(nvim):
    nvim.command("""silent normal! mx%"sy%`x""")
    data = "(require '{})".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSend', data, "clojure")


def lein_import(nvim):
    nvim.command("""silent normal! mx%"sy%`x""")
    data = "(import '{})".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSend', data, "clojure")


def lein_require_file(nvim):
    nvim.command("""silent normal! mxggf w"sy$`x""")
    data = "(require '[{}] :reload)".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSend', data, "clojure")


def lein_require_with_ns(nvim):
    nvim.call("inputsave")
    ns = nvim.call("input", "iron> with alias: ")
    nvim.call("inputrestore")
    nvim.command("""silent normal! mxggf w"sy$`x""")
    data = "(require '[{} :as {}] :reload)".format(
        nvim.funcs.getreg('s'), ns
    )
    return nvim.call('IronSend', data, "clojure")


def lein_send(nvim):
    nvim.command("""
exec "normal! mx"
exec "?^("
exec 'silent normal! "sya(`x'
nohl""".replace("\n", " | "))
    return nvim.call('IronSend', nvim.funcs.getreg('s'), "clojure")


def lein_load_facts(nvim):
    nvim.command("""silent normal! mxggf w"sy$`x""")
    data = "(load-facts '{})".format(nvim.funcs.getreg('s'))
    return nvim.call('IronSend', data, "clojure")

repl = {
    'command': 'lein repl',
    'language': 'clojure',
    'detect': lambda *args, **kwargs: True,
    'mappings': [
        ('<leader>so', 'require', lein_require),
        ('<leader>si', 'import', lein_import),
        ('<leader>sr', 'require_file', lein_require_file),
        ('<leader>sR', 'require_with_ns', lein_require_with_ns),
        ('<leader>ss', 'send', lein_send),
        ('<leader>sm', 'midje', lein_load_facts),
    ]
}
