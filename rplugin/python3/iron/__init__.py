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

@neovim.plugin
class Iron(object):

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

    # Actual Fns
    def open_repl_for(self, ft):
        log.info("Opening repl for {}".format(ft))
        repl = self.set_repl_for_ft(ft)

        if not repl:
            msg = "No repl found for {}".format(ft)
            log.info(msg)
            self.call_cmd("echomsg '{}'".format(msg))
            return

        repl_id = self.termopen(repl['command'])

        self.set_mappings(repl, ft)
        self.call_hooks(ft)

        self.__repl[ft]['repl_id'] = repl_id
        self.set_variable(
            "iron_{}_repl".format(ft), self.__nvim.current.buffer.number
        )

        return repl_id

    def sanitize_multiline(self, data):
        repl = self.__repl.get(self.get_ft())
        multiline = repl['multiline']
        if "\n" in data and repl:
            if len(multiline) == 3:
                (pre, post, extra) = multiline
            else:
                (pre, post) = multiline
                extra = None

            log.info("Multinine string supplied.")
            return ("{}\n{}{}".format(pre, data, post), extra)

        log.info("String was not multiline. Continuing")
        return (data, None)

    @neovim.command("IronPromptRepl")
    def prompt_query(self):
        self.open_repl_for(self.prompt("repl type"))

    @neovim.command("IronRepl")
    def get_repl(self):
        self.open_repl_for(self.get_ft())

    @neovim.command("IronClearReplDefinition")
    def clear_repl_definition(self):
        self.clear_repl_for_ft(self.prompt("repl type"))

    @neovim.command("IronClearReplDefinition")
    def clear_repl_definition(self):
        self.clear_repl_for_ft(self.get_ft())

    @neovim.function("IronSendSpecial")
    def mapping_send(self, args):
        fn = self.get_current_bindings().get(args[0])
        if fn:
            fn(self)

    @neovim.function("IronSendMotion")
    def send_motion_to_repl(self, args):
        if args[0] == 'line':
            self.call_cmd("""normal! '[V']"sy""")
        else:
            self.call_cmd("""normal! `[v`]"sy""")

        return self.send_to_repl([self.__nvim.funcs.getreg('s')])

    @neovim.function("IronSend")
    def send_to_repl(self, args):
        repl = self.__repl.get(args[1]) if len(args) > 1 else None
        repl = repl or self.get_current_repl()

        if not repl:
            return None

        log.info("Sending data to repl -> {}".format(repl))

        if 'multiline' in repl:
            log.info("Multiline statement allowed - wrapping")
            data, extra = self.sanitize_multiline(args[0])
        else:
            log.info("Plain string - no multiline")
            data = "{}\n".format(args[0])
            extra = None

        self.send_data(data, repl)

        if extra is not None:
            self.send_data(extra, repl)
