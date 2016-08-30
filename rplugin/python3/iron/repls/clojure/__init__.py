# encoding:utf-8
"""Leiningen repl definition for iron.nvim. """
from iron.repls.utils.cmd import detect_fn
from iron.repls.clojure.lein import *

repl = {
    'command': 'lein repl',
    'language': 'clojure',
    'detect': detect_fn('lein'),
    'nrepl': {'protocol': 'file', 'uri': '.nrepl-port'}
    'mappings': [
        ('<leader>so', 'require', lein_require),
        ('<leader>si', 'import', lein_import),
        ('<leader>sr', 'require_file', lein_require_file),
        ('<leader>sR', 'require_with_ns', lein_require_with_ns),
        ('<leader>s.', 'prompt_require', lein_prompt_require),
        ('<leader>s/', 'prompt_require_as', lein_prompt_require_as),
        ('<leader>ss', 'send', lein_send),
        ('<leader>sm', 'midje', lein_load_facts),
    ]
}
