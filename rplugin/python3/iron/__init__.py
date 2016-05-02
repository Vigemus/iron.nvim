# encoding:utf-8
""" iron.nvim (Interactive Repls Over Neovim).

`iron` is a plugin that allows better interactions with interactive repls
using neovim's job-control and terminal.
"""

import neovim


@neovim.plugin
class Iron(object):

    def __init__(self, nvim):
        self.__nvim = nvim
        self.__repls = {}

    @neovim.function("IronOpenRepl")
    def open_repl(self, args):
        self.__nvim.command("echo {}".format(args))
