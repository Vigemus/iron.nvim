# encoding:utf-8
""" iron.nvim (Interactive Repls Over Neovim).

This is the base structure to allow iron to interact with neovim.
"""
import logging
import neovim
import os
from iron.repls import available_repls

logger = logging.getLogger(__name__)

if 'NVIM_IRON_DEBUG_FILE' in os.environ:
    logfile = os.environ['NVIM_IRON_DEBUG_FILE'].strip()
    logger.addHandler(logging.FileHandler(logfile, 'w'))

logger.level = logging.DEBUG

class BaseIron(object):

    def __init__(self, nvim):
        self.__nvim = nvim
        self.__repl = {}

    def _list_repl_templates(self, ft):
        return list(filter(
            lambda k: ft == k['language'] and
            k['detect'](iron=self),
            available_repls
        ))

    def _get_repl_template(self, ft):
        logger.info("Trying to find a repl definition for ft {}".format(ft))

        repls = self._list_repl_templates(ft)

        logger.info('Got {} as repls for {}'.format(
            [i['command'] for i in repls], ft
        ))

        #TODO Prompt user to choose for a repl or open first if Cmd!
        return len(repls) and repls[0] or {}

    # Helper fns
    def has_repl_defined(self, ft):
        return ft in self.__repl

    def has_repl_template(self, ft):
        return bool(self._list_repl_templates(ft))

    def termopen(self, cmd):
        repl_open_cmd = self.get_variable('iron_repl_open_cmd', 'botright spl')
        self.call_cmd(
            "{} | enew | exec bufwinnr(bufnr('$')).'wincmd w'".format(
                repl_open_cmd
            ))

        return self.call('termopen', cmd)

    def get_ft(self):
        return self.__nvim.current.buffer.options["ft"]

    def get_repl(self, ft):
        return self.__repl.get(ft)

    def get_current_repl(self):
        return self.get_repl(self.get_ft())

    def get_current_bindings(self):
        return self.get_current_repl().get('fns', {})

    def send_data(self, data, repl=None):
        repl = repl or self.get_current_repl()
        logger.info('Sending data to repl ({}):\n{}'.format(
            repl['repl_id'], data
        ))

        self.call('jobsend', repl["repl_id"], data)

    def get_repl_for_ft(self, ft):
        if ft not in self.__repl:
            logger.debug("Getting repl definition for {}".format(ft))
            repl = self._get_repl_template(ft)

            if not repl:
                logger.debug("echo 'No repl for {}'".format(ft))
                return None

            self.__repl[ft] = repl

        return self.__repl[ft]

    def set_repl_id(self, repl, repl_id):
        ft = repl['language']
        logger.info("Storing repl id {} for ft {}".format(repl_id, ft))
        self.__repl[ft]['repl_id'] = repl_id
        self.set_variable(
            "iron_{}_repl".format(ft), self.__nvim.current.buffer.number
        )


    def clear_repl_for_ft(self, ft):
        logger.debug("Clearing repl definitions for {}".format(ft))
        for m in self.__repl[ft]['mapped_keys']:
            logger.debug("Unmapping keys {}".format(m))
            self.call_cmd("unmap {}".format(m))

        del self.__repl[ft]

    def call_cmd(self, cmd):
        logger.debug("Calling cmd {}".format(cmd))
        return self.__nvim.command_output(cmd)

    def call(self, cmd, *args):
        logger.debug("Calling function {} with args {}".format(cmd, args))
        return self.__nvim.call(cmd, *args)

    def register(self, reg):
        logger.debug("Getting register {}".format(reg))
        return self.__nvim.funcs.getreg(reg)

    def set_register(self, reg, data):
        logger.info("Setting register '{}' with value '{}'".format(reg, data))
        return self.__nvim.funcs.setreg(reg, data)

    def set_variable(self, var, data):
        logger.info("Setting variable '{}' with value '{}'".format(var, data))
        self.__nvim.vars[var] = data

    def unset_variable(self, var):
        logger.info("Unsetting variable '{}'".format(var))
        del self.__nvim.vars[var]

    def has_variable(self, var):
        return var in self.__nvim.vars

    def get_variable(self, var, default=""):
        return self.__nvim.vars.get(var) or default

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

    def dump_repl_dict(self):
        logger.warning("#-- Dumping repl definitions --#")
        logger.warning(self.__repl)
        logger.warning("#--   End of repl def dump   --#")

    def set_mappings(self, repl):
        ft = repl['language']
        self.__repl[ft]['fns'] = {}
        self.__repl[ft]['mapped_keys'] = []
        add_mappings = self.__repl[ft]['mapped_keys'].append

        logger.info("Mapping special functions for {}".format(ft))
        logger.debug("Available mappings are: {}".format(repl.get("mappings")))

        base_cmd = 'nnoremap <silent> {} :call IronSendSpecial("{}")<CR>'

        for k, n, c in repl.get('mappings', []):
            logger.info("Mapping '{}' to function '{}'".format(k, n))

            self.call_cmd(base_cmd.format(k, n))
            self.__repl[ft]['fns'][n] = c
            add_mappings(k)

    def call_hooks(self, repl):
        curr_buf = self.__nvim.current.buffer.number
        ft = repl['language']

        hooks = filter(None, (
            self.get_list_variable("iron_new_repl_hooks") +
            self.get_list_variable('iron_new_{}_repl_hooks'.format(ft))
        ))

        logger.info("Got this hook function list: {}".format(hooks))

        [self.call(i, curr_buf) for i in hooks]
