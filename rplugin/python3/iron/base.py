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

class EmptyPromptError(Exception):
    """ User aborted prompt. """
    pass

class BaseIron(object):

    def __init__(self, nvim):
        self.__nvim = nvim
        self.__repl = {}
        self.global_mappings = {
            "fns": {},
            "mapped_keys": [],
        }

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

    def term_placement(self):
        self.call_cmd(
            "{} | enew | exec bufwinnr(bufnr('$')).'wincmd w'".format(
                self.get_variable('iron_repl_open_cmd', 'botright spl')
            ))


    def termopen(self, cmd, with_placement=True):
        if with_placement:
            self.term_placement()
        return self.call('termopen', cmd)


    def get_ft(self):
        return self.__nvim.current.buffer.options["ft"]

    def get_pwd(self):
        return self.__nvim.funcs.getcwd(-1, 0)

    def get_repl(self, ft):
        return self.__repl.get(ft, {})

    def get_current_repl(self):
        return self.get_repl(self.get_ft())

    def get_current_bindings(self):
        bindings = self.global_mappings['fns']
        bindings.update(self.get_current_repl().get('fns', {}))

        return bindings

    def send_data(self, data, repl=None):
        ft = self.get_ft()
        repl = repl or self.get_repl(ft)
        repl_id = repl['instances'].get(self.get_pwd())

        if repl_id is None:
            repl_id = self.__nvim.current.tabpage.vars[
                "iron_{}_repl_id".format(ft)
            ]

        logger.info('Sending data to repl ({}):\n{}'.format(repl_id, data))

        self.call('jobsend', repl_id, data)

    def get_template_for_ft(self, ft):
        logger.debug("Getting repl definition for {}".format(ft))
        repl = self._get_repl_template(ft)

        if not repl:
            logger.debug("echo 'No repl for {}'".format(ft))
            return None

        return repl

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

        if not ret:
            raise EmptyPromptError(msg)

        return ret

    def dump_repl_dict(self):
        logger.warning("#-- Dumping repl definitions --#")
        logger.warning(self.__repl)
        logger.warning("#--   End of repl def dump   --#")

    def set_mappings(self, template, repl_definition):
        ft = template['language']

        logger.info("Mapping special functions for {}".format(ft))
        logger.debug(
            "Available mappings are: {}".format(template.get("mappings"))
        )

        base_cmd = 'nnoremap <silent> {} :call IronSendSpecial("{}")<CR>'
        map_keys = lambda key, name: self.call_cmd(base_cmd.format(key, name))

        for k, n, c in template.get('mappings', []):
            logger.info("Mapping '{}' to function '{}'".format(k, n))

            map_keys(k, n)

            repl_definition['fns'][n] = c
            repl_definition['mapped_keys'].append(k)

        logger.info("Mapping global functions for {}".format(ft))
        logger.debug(
            "Available mappings are: {}".format(template.get("global_mappings"))
        )

        for k, n, c in template.get('global_mappings', []):
            logger.info("Mapping '{}' to function '{}'".format(k, n))

            map_keys(k, n)

            self.global_mappings['fns'][n] = c
            self.global_mappings['mapped_keys'].append(k)

        return repl_definition


    def call_hooks(self, repl_definition):
        ft = repl_definition['ft']
        curr_buf = self.__nvim.current.buffer.number

        hooks = filter(None, (
            self.get_list_variable("iron_new_repl_hooks") +
            self.get_list_variable('iron_new_{}_repl_hooks'.format(ft))
        ))

        logger.info("Got this list of hook functions: {}".format(hooks))

        [self.call(i, curr_buf, repl_definition) for i in hooks]

    def bind_repl(self, repl_definition, repl_id):
        ft = repl_definition['ft']
        pwd = self.__nvim.funcs.getcwd(-1, 0)

        logger.info("Storing repl id {} for ft {}".format(repl_id, ft))
        repl_definition['instances'][pwd] = repl_id

        return repl_definition

    def post_process(self, repl_definition, repl_id, detached=False):
        if detached:
            self.__nvim.current.tabpage.vars[
                "iron_{}_repl_id".format(repl_definition['ft'])
            ] = repl_id
        else:
            repl_definition = self.bind_repl(repl_definition, repl_id)

        self.call_hooks(repl_definition)

        return repl_definition


    def build_from_template(self, template, command, with_placement):
        ft = template['language']
        repl_definition = {
            'ft': ft,
            'fns': {},
            'mapped_keys': [],
            'instances': {},
        }

        return self.set_mappings(template, repl_definition)

    def open_repl(self, template, **kwargs):
        ft = template['language']
        pwd = self.get_pwd()
        command = kwargs.get('command', template['command'])
        with_placement = kwargs.get('with_placement', True)
        detached = kwargs.get('detached', False)

        if not self.has_repl_defined(ft):
            repl_id = self.termopen(command, with_placement)
            repl_definition = self.build_from_template(
                template, command, with_placement
            )
            self.__repl[ft] = self.post_process(
                repl_definition, repl_id, detached
            )


        elif not pwd in self.__repl[ft]['instances']:
            repl_id = self.termopen(command, with_placement)
            self.__repl[ft] = self.post_process(
                self.__repl[ft], repl_id, detached
            )

        elif self.__nvim.funcs.bufwinnr(
                self.__repl[ft]['instances'][pwd]) == -1:

            if with_placement:
                self.term_placement()

            self.call_cmd("b {}".format(self.__repl[ft]['instances'][pwd]))

