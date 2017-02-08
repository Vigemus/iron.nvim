# encoding:utf-8
"""Leiningen repl definition for iron.nvim. """
import os
from functools import partial
from iron.repls.clojure.utils import *


def lein_switch_ns(iron):
    data = "(in-ns '{})".format(get_current_ns(iron))
    return iron.send_to_repl((data, "clojure"))

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
