# encoding:utf-8
"""Leiningen repl definition for iron.nvim. """

def get_current_parens(iron):
    iron.call_cmd("""silent normal! mx%"sy%`x""")
    return iron.register('s')


def get_current_ns(iron):
    iron.call_cmd("""silent normal! mxggf w"sy$`x""")
    return iron.register('s')


def lein_require(iron):
    data = "(require '{})".format(get_current_parens(iron))
    return iron.send_to_repl((data, "clojure"))


def lein_import(iron):
    data = "(import '{})".format(get_current_parens(iron))
    return iron.send_to_repl((data, "clojure"))


def lein_require_file(iron):
    data = "(require '[{}] :reload)".format(get_current_ns(iron))
    return iron.send_to_repl((data, "clojure"))


def lein_require_with_ns(iron):
    iron.call("inputsave")
    ns = iron.call("input", "iron> with alias: ")
    iron.call("inputrestore")
    data = "(require '[{} :as {}] :reload)".format(
        get_current_ns(iron), ns
    )
    return iron.send_to_repl((data, "clojure"))


def lein_send(iron):
    iron.call_cmd("""
exec "normal! mx"
exec "?^("
exec 'silent normal! "sya(`x'
nohl""".replace("\n", " | "))
    return iron.send_to_repl((iron.register('s'), "clojure"))


def lein_load_facts(iron):
    data = "(load-facts '{})".format(get_current_ns(iron))
    return iron.send_to_repl((data, "clojure"))

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
