# encoding:utf-8
"""Leiningen repl definition for iron.nvim. """
from iron.repls.utils.cmd import detect_fn
from iron.repls.clojure.lein import *
from iron.repls.clojure.midje import *

mappings = [
    ('<leader>so', 'require', lein_require),
    ('<leader>si', 'import', lein_import),
    ('<leader>sr', 'require-file', lein_require_file),
    ('<leader>sR', 'require-with-ns', lein_require_with_ns),
    ('<leader>s.', 'prompt-require', lein_prompt_require),
    ('<leader>s/', 'prompt-require-as', lein_prompt_require_as),
    ('<leader>ss', 'send-block', lein_send),

    ('<leader>mf', 'midje-load-facts', midje_load_facts),
    ('<leader>ma', 'midje-autotest', midje_autotest),
]

repl = {
    'command': 'lein repl',
    'language': 'clojure',
    'detect': detect_fn('lein'),
    'mappings': mappings
}

boot = {
    'command': 'boot repl',
    'language': 'clojure',
    'detect': detect_fn('boot'),
    'mappings': mappings
}
