# encoding:utf-8
"""Leiningen repl definition for iron.nvim. """

def send_object_to_repl(nvim):
    pass


repl = {
    'command': 'lein repl',
    'language': 'clojure',
    'mappings': [
        ('so', send_object_to_repl),
    ]
}
