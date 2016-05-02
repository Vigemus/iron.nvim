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
        self.__current = -1

        nvim.command("nmap <silent> str :set opfunc=IronSendToRepl<CR>g@")

    @neovim.function("IronOpenRepl")
    def open_repl(self, args):
        self.__nvim.call('termopen', args)
        repl = args[0]
        repl_id = self.__nvim.call('termopen', repl)

        self.__repls[repl_id] = repl_id
        self.__current = repl_id

    @neovim.function("IronSendToRepl")
    def send_to_repl(self, args):
        if args[0] == 'line':
            self.__nvim.command("""normal! '[V']"sy""")
        else:
            self.__nvim.command("""normal! `[v`]"sy""")

        data = self.__nvim.funcs.getreg('s')
        self.__nvim.call('jobsend', self.__current, data)
