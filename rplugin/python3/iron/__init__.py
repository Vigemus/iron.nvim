# encoding:utf-8
""" iron.nvim (Interactive Repls Over Neovim).

`iron` is a plugin that allows better interactions with interactive repls
using neovim's job-control and terminal.
"""
import neovim
from iron.repls import available_repls


@neovim.plugin
class Iron(object):

    def __init__(self, nvim):
        self.__nvim = nvim
        self.__repls = {}
        self.__current = -1

    def get_repl_template(self, ft):
        ft_repl = "iron_{}_repl".format(ft)

        if ft_repl in self.__nvim.vars:
            return self.__nvim.vars[ft_repl]
        else:
            repls = list(filter(lambda k: ft in k['languages'],
                available_repls))
            # TODO Wiser choosing
            return len(repls) and repls[0]['command'] or ""

    @neovim.function("IronOpenRepl")
    def open_repl_for(self, args):
        self.__nvim.command('spl | wincmd j | enew')
        repl_id = self.__nvim.call('termopen', args[0])

        self.__repls[repl_id] = list(filter(lambda k: args[0] == k['command'],
            available_repls))[0]

        self.__current = repl_id
        return repl_id

    @neovim.command("IronRepl")
    def get_repl(self):
        ft = self.__nvim.current.buffer.options["ft"]
        repl_type = self.get_repl_template(ft)

        if repl_type == "":
            self.__nvim.command("echoerr 'No repl found for {}'".format(ft))
        else:
            repl_id = self.open_repl_for([repl_type])
            self.__nvim.vars["iron_current_repl"] = repl_id

    @neovim.function("IronSendToRepl")
    def send_to_repl(self, args):
        if args[0] == 'line':
            self.__nvim.command("""normal! '[V']"sy""")
        else:
            self.__nvim.command("""normal! `[v`]"sy""")

        data = self.__nvim.funcs.getreg('s')

        multiline = 'multinine' in self.__repls[self.__current]

        if multiline and\
                any(map(lambda k: not k or k.isspace(), data.split('\n'))):
            (pre, post) = self.__repls[self.__current]['multiline']
            data = "{}\n{}\n{}".format(pre, data, post)

        data += "\n"

        self.__nvim.call('jobsend', self.__current, data)
