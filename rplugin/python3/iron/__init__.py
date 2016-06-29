# encoding:utf-8
""" iron.nvim (Interactive Repls Over Neovim).

`iron` is a plugin that allows better interactions with interactive repls
using neovim's job-control and terminal.

Currently it keeps track of a single repl instance per filetype.
"""
import neovim
from iron.repls import available_repls


@neovim.plugin
class Iron(object):

    def __init__(self, nvim):
        self.__nvim = nvim
        self.__repl = {}

    def get_repl_template(self, ft):
        repls = list(filter(
            lambda k: ft == k['language'] and k['detect'](),
            available_repls))

        return len(repls) and repls[0] or {}

    # Helper fns
    def termopen(self, cmd):
        return self.__nvim.call('termopen', cmd)

    def get_ft(self):
        return self.__nvim.current.buffer.options["ft"]

    def get_current_repl(self):
        return self.__repl.get(self.get_ft())

    def send_data(self, data, repl=None):
        repl = repl or self.get_current_repl()
        self.__nvim.call('jobsend', repl["repl_id"], data)

    # Actual Fns
    def open_repl_for(self, ft):
        self.__nvim.command('spl | wincmd j | enew')

        repl_id = self.termopen(self.__repl[ft]['command'])

        # TODO Make optional nvimux integration detached
        self.__nvim.current.buffer.vars['nvimux_buf_orientation'] = (
            "botright split"
        )

        base_cmd = 'nnoremap <silent> {} :call IronSendSpecial("{}")<CR>'

        for k, n, c in self.__repl[ft].get('mappings', []):
            self.__nvim.command(base_cmd.format(k, n))
            self.__repl['fns'][n] = c

        self.__repl[ft]['repl_id'] = repl_id

        return repl_id

    def sanitize_multiline(self, data):
        repl = self.__repl.get(self.get_ft())
        if "\n" in data and repl:
            (pre, post) = repl['multiline']
            return "{}\n{}\n{}".format(pre, data, post)
        return data

    @neovim.command("IronRepl")
    def get_repl(self):
        ft = self.get_ft()

        repl_type = self.__repl[ft] = self.get_repl_template(ft)

        if not repl_type:
            self.__nvim.command("echoerr 'No repl found for {}'".format(ft))
            return

        self.open_repl_for(ft)
        self.__nvim.vars["iron_{}_repl".format(ft)] = \
            self.__nvim.current.buffer.number

    @neovim.function("IronSendSpecial")
    def mapping_send(self, args):
        return self.__repl['fns'][args[0]](self.__nvim)

    @neovim.function("IronSendMotion")
    def send_motion_to_repl(self, args):
        if args[0] == 'line':
            self.__nvim.command("""normal! '[V']"sy""")
        else:
            self.__nvim.command("""normal! `[v`]"sy""")

        return self.send_to_repl([self.__nvim.funcs.getreg('s')])

    @neovim.function("IronSend")
    def send_to_repl(self, args):
        repl = self.__repl.get(args[1]) if len(args) > 1 else None
        repl = repl or self.get_current_repl()

        if not repl:
            return None

        if 'multinine' in repl:
            data = self.sanitize_multiline(args[0])
        else:
            data = "{}\n".format(args[0])

        return self.send_data(data, repl)
