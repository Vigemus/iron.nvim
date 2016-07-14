# encoding:utf-8
"""OCaml repl definitions for iron.nvim. """

def detect_ocaml_repl(repl):
    """Checks whether a executable exists.
    :returns: True
    """
    from distutils.spawn import find_executable
    return find_executable(repl) is not None
    
ocamltop = {
    'command': 'ocamltop',
    'language': 'ocaml',
    'detect': lambda *args, **kwargs: detect_ocaml_repl('ocamltop')
}

utop = {
    'command': 'utop',
    'language': 'ocaml',
    'detect': lambda *args, **kwargs: detect_ocaml_repl('utop')
}
