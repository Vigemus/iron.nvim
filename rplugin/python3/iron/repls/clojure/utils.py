# encoding:utf-8
"""Util functions for clojure development"""

def get_current_parens(iron):
    iron.call_cmd("""silent normal! mx%"sy%`x""")
    return iron.register('s')


def get_current_ns(iron):
    # Acid is much better at finding the ns than Iron..
    if iron.nvim.funcs.exists('*AcidGetNs'):
        return iron.nvim.funcs.AcidGetNs()

    iron.call_cmd("""silent normal! mxggf w"sy$`x""")
    return iron.register('s')

def get_outermost_parens(iron):
    iron.call_cmd('''exec 'normal! mx?^("sya(`x' | nohl''')
    return iron.register('s')


