# encoding:utf-8
"""Leiningen repl definition for iron.nvim. """
import os
from functools import partial


# Get Data
def get_current_parens(iron):
    iron.call_cmd("""silent normal! mx%"sy%`x""")
    return iron.register('s')


def get_current_ns(iron):
    iron.call_cmd("""silent normal! mxggf w"sy$`x""")
    return iron.register('s')

def get_outermost_parens(iron):
    iron.call_cmd('''exec 'normal! mx?^("sya(`x' | nohl''')
    return iron.register('s')

def lein_require(iron):
    data = "(require '{})".format(get_current_parens(iron))
    return iron.send_to_repl((data, "clojure"))


def lein_import(iron):
    data = "(import '{})".format(get_current_parens(iron))
    return iron.send_to_repl((data, "clojure"))


# Transform data
def lein_require_file(iron):
    data = "(require '[{}] :reload)".format(get_current_ns(iron))
    return iron.send_to_repl((data, "clojure"))


def lein_require_with_ns(iron):
    ns = iron.prompt("with alias")
    data = "(require '[{} :as {}])".format(
        get_current_ns(iron), ns
    )
    return iron.send_to_repl((data, "clojure"))


def lein_send(iron):
    return iron.send_to_repl((get_outermost_parens(iron), "clojure"))


def lein_load_facts(iron):
    data = "(load-facts '{})".format(get_current_ns(iron))
    return iron.send_to_repl((data, "clojure"))

def midje_autotest(iron):
    return iron.send_to_repl(("(autotest)", "clojure"))


def lein_prompt_require(iron):
    try:
        require = iron.prompt("require file")
    except:
        iron.call_cmd("echo 'Aborting'")
    else:
        data = "(require '[{}])".format(require)
        return iron.send_to_repl((data, "clojure"))


def lein_prompt_require_as(iron):
    try:
        require = iron.prompt("require file")
        alias = iron.prompt("as")
    except:
        iron.call_cmd("echo 'Aborting'")
    else:
        data = "(require '[{} :as {}])".format(require, alias)
        return iron.send_to_repl((data, "clojure"))


# send data
def nrepl_eval(iron, data):
    "requires nrepl-python-client"
    try:
        import nrepl
    except:
        iron.call_cmd("echomsg 'Unable to eval - missing nREPL client lib'")
        return

    vim_pwd = iron.call("getcwd")

    with open(os.path.join(vim_pwd, ".nrepl-port")) as port:
        c = nrepl.connect("nrepl://localhost:{}".format(port.read()))

    c.write({"op": "eval", "code": data})
    r = c.read()

    if 'out' in r:
        value = r['out']
        r = c.read()
        value = value if r['value'] == u'nil' else r['value']
    elif 'ex' in r:
        iron.call_cmd("echomsg 'An error occurred: {}\n{}'".format(
            r['ex'], c.read()['err']
        ))
        value = None
    else:
        value = r.get('value', None)

    c.close()
    return value


# eval data
def lein_prompt_eval(iron):
    try:
        cmd = iron.prompt("cmd")
    except:
        iron.call_cmd("echo 'Aborting'")
    else:
        ret = nrepl_eval(iron, cmd)
        iron.call_cmd("echomsg '{}'".format(ret))

def lein_update_data_with_fn(iron):
    try:
        cmd = iron.prompt("cmd")
    except:
        iron.call_cmd("echo 'Aborting'")
    else:
        data = get_current_parens(iron)
        ret = nrepl_eval(iron, "({} {})".format(cmd, data))

        if ret is None:
            iron.call_cmd("echo 'Error with eval, aborting.'")
            return

        iron.set_register("s", ret)
        iron.call_cmd("""silent normal! mx%v%"sp`x""")
