# encoding:utf-8
""" Midje bindings and special functions iron.nvim. """

def midje_load_facts(iron):
    data = "(load-facts '{})".format(get_current_ns(iron))
    return iron.send_to_repl((data, "clojure"))

def midje_autotest(iron):
    return iron.send_to_repl(("(autotest)", "clojure"))



