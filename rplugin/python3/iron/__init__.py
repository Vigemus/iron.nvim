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
        self.__repl_templates = {
            'python': lambda: (
                nvim.eval("executable('ipython')") and "ipython" or "python"
            )
        }
        self.__current = -1

        nvim.command("nmap <silent> str :set opfunc=IronSendToRepl<CR>g@")

    @neovim.function("IronOpenRepl")
    def open_repl_for(self, args):
        self.__nvim.call('termopen', args)
        repl = args[0]
        self.__nvim.command("vsp")
        repl_id = self.__nvim.call('termopen', repl)
        self.__nvim.command("q")

        self.__repls[repl_id] = repl_id
        self.__current = repl_id

    @neovim.command("IronRepl")
    def get_repl(self):
        ft = self.__nvim.current.buffer.options["ft"]
        repl_type = self.__repl_templates.get(ft, lambda: "")()
        if repl_type == "":
            self.__nvim.command("echoerr 'No repl found for {}'".format(ft))
            return
        self.open_repl_for(repl_type)

    @neovim.function("IronSendToRepl")
    def send_to_repl(self, args):
        if args[0] == 'line':
            self.__nvim.command("""normal! '[V']"sy""")
        else:
            self.__nvim.command("""normal! `[v`]"sy""")

        data = self.__nvim.funcs.getreg('s')
        self.__nvim.call('jobsend', self.__current, data)
