# encoding:utf-8
""" iron.nvim (Interactive Repls Over Neovim).

`iron` is a plugin that allows better interactions with interactive repls
using neovim's job-control and terminal.

Currently it keeps track of a single repl instance per filetype.
"""
import logging
import neovim
from iron.repls import available_repls

log = logging.getLogger(__name__)
log.setLevel(logging.DEBUG)


class BaseIron(object):

    def __init__(self, nvim):
        self.__nvim = nvim
        self.__repl = {}

        debug_path = (
            'iron_debug' in nvim.vars and './.iron_debug.log'
            or nvim.vars.get('iron_debug_path')
        )

        if debug_path is not None:
            fh = logging.FileHandler(debug_path)
            fh.setLevel(logging.DEBUG)
            log.addHandler(fh)


    def get_repl_template(self, ft):
        repls = list(filter(
            lambda k: ft == k['language'] and k['detect'](),
            available_repls))

        log.info('Got {} as repls for {}'.format(
            [i['command'] for i in repls], ft
        ))

        return len(repls) and repls[0] or {}

    # Helper fns
    def termopen(self, cmd):
        self.call_cmd('spl | wincmd j | enew')

        return self.call('termopen', cmd)

    def get_ft(self):
        return self.__nvim.current.buffer.options["ft"]

    def get_current_repl(self):
        return self.__repl.get(self.get_ft())

    def get_current_bindings(self):
        return self.get_current_repl().get('fns', {})

    def send_data(self, data, repl=None):
        repl = repl or self.get_current_repl()
        log.info('Sending data to repl ({}):\n{}'.format(
            repl['repl_id'], data
        ))

        self.call('jobsend', repl["repl_id"], data)

    def set_repl_for_ft(self, ft):
        if ft not in self.__repl:
            log.debug("Adding repl definition for {}".format(ft))
            self.__repl[ft] = self.get_repl_template(ft)

        return self.__repl[ft]

    def clear_repl_for_ft(self, ft):
        log.debug("clearing repl definitions for {}".format(ft))
        for m in self.__repl[ft]['mappings']:
            log.debug("unmapping keys {}".format(m))
            self.call_cmd("umap {}".format(m))

        del self.__repl[ft]

    def call_cmd(self, cmd):
        log.debug("calling cmd {}".format(cmd))
        return self.__nvim.command(cmd)

    def call(self, cmd, *args):
        log.debug("calling function {} with args {}".format(cmd, args))
        return self.__nvim.call(cmd, *args)

    def register(self, reg):
        log.debug("getting register {}".format(reg))
        return self.__nvim.funcs.getreg(reg)

    def set_register(self, reg, data):
        log.info("Setting register '{}' with value '{}'".format(reg, data))
        return self.__nvim.funcs.setreg(reg, data)

    def set_variable(self, var, data):
        log.info("Setting variable '{}' with value '{}'".format(var, data))
        self.__nvim.vars[var] = data

    def has_variable(self, var):
        return var in self.__nvim.vars

    def get_variable(self, var):
        return self.__nvim.vars.get(var)

    def get_list_variable(self, var):
        v = self.get_variable(var)

        if v is None:
            return []
        elif not isinstance(v, list):
            return [v]
        else:
            return v


    def prompt(self, msg):
        self.call("inputsave")
        ret = self.call("input", "iron> {}: ".format(msg))
        self.call("inputrestore")
        return ret

    def set_mappings(self, repl, ft):
        self.__repl[ft]['fns'] = {}
        self.__repl[ft]['mappings'] = []
        add_mappings = self.__repl[ft]['mappings'].append
        base_cmd = 'nnoremap <silent> {} :call IronSendSpecial("{}")<CR>'

        for k, n, c in repl.get('mappings', []):
            log.info("Mapping '{}' to function '{}'".format(k, n))

            self.call_cmd(base_cmd.format(k, n))
            self.__repl[ft]['fns'][n] = c
            add_mappings(k)

    def call_hooks(self, ft):
        curr_buf = self.__nvim.current.buffer.number

        hooks = (
            self.get_list_variable("iron_new_repl_hooks") +
            self.get_list_variable('iron_new_{}_repl_hooks'.format(ft))
        )

        log.info("got this hook function list: {}".format(hooks))

        [self.call(i, curr_buf) for i in hooks]


