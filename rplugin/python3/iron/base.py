# encoding:utf-8
""" iron.nvim (Interactive Repls Over Neovim).

This is the base structure to allow iron to interact with neovim.
"""
import logging
import neovim
import os
from iron.zen.ui import (
    prompt, toggleable_buffer, build_window, EmptyPromptError,
    open_term
)
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
        self.nvim = nvim
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

    def term_placement(self, buf_id=None):
        self.call_cmd(
            " | ".join([
                self.get_variable('iron_repl_open_cmd', 'botright spl'),
                "b {}".format(buf_id) if buf_id is not None else 'enew',
                "exec bufwinnr(bufnr('$')).'wincmd w'"
            ]))


    def termopen(self, cmd, with_placement=True):
        if with_placement:
            self.term_placement()
        return open_term(self.nvim, cmd)


    def get_ft(self):
        return self.nvim.current.buffer.options["ft"]

    def get_pwd(self):
        return self.nvim.funcs.getcwd(-1, 0)

    def get_repl(self, ft):
        return self.__repl.get(ft, {})

    def get_current_repl(self):
        return self.get_repl(self.get_ft())

    def get_current_bindings(self):
        bindings = self.global_mappings['fns']
        bindings.update(self.get_current_repl().get('fns', {}))

        return bindings

    def send_data(self, data, repl):
        ft = repl['ft']

        instance = repl['instances'].get(self.get_pwd())

        if instance is None:
            key = "iron_{}_repl_id".format(ft)
            logger.info('Finding target repl via `{}`'.format(key))
            repl_id = self.nvim.current.tabpage.vars[key]
        else:
            repl_id = instance['repl_id']

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
        return self.nvim.command_output(cmd)

    def call(self, cmd, *args):
        logger.debug("Calling function {} with args {}".format(cmd, args))
        return self.nvim.call(cmd, *args)

    def register(self, reg):
        logger.debug("Getting register {}".format(reg))
        return self.nvim.funcs.getreg(reg)

    def set_register(self, reg, data):
        logger.info("Setting register '{}' with value '{}'".format(reg, data))
        return self.nvim.funcs.setreg(reg, data)

    def set_variable(self, var, data):
        logger.info("Setting variable '{}' with value '{}'".format(var, data))
        self.nvim.vars[var] = data

    def unset_variable(self, var):
        logger.info("Unsetting variable '{}'".format(var))
        del self.nvim.vars[var]

    def has_variable(self, var):
        return var in self.nvim.vars

    def get_variable(self, var, default=""):
        return self.nvim.vars.get(var) or default

    def get_list_variable(self, var):
        v = self.get_variable(var)

        if v is None:
            return []
        elif not isinstance(v, list):
            return [v]
        else:
            return v


    def prompt(self, msg):
        logger.info('Calling {} prompt'.format(msg))
        ret = prompt(self.nvim, 'iron> {}:'.format(msg))
        logger.debug('Got {} back'.format(ret))
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
        pwd = self.nvim.funcs.getcwd(-1, 0)

        hooks = list(filter(None, (
            self.get_list_variable("iron_new_repl_hooks") +
            self.get_list_variable('iron_new_{}_repl_hooks'.format(ft))
        )))

        logger.info("Got this list of hook functions: {}".format(hooks))

        payload = dict.copy(repl_definition)
        del payload['fns']
        buf_id = self.nvim.current.buffer.number

        [self.call(i, buf_id, payload) for i in hooks]

    def bind_repl(self, repl_definition, repl_id):
        ft = repl_definition['ft']
        pwd = self.nvim.funcs.getcwd(-1, 0)

        logger.info("Storing repl id {} for ft {}".format(repl_id, ft))
        repl_definition['instances'][pwd] = {
            'repl_id': repl_id,
            'buf_id': self.nvim.current.buffer.number
        }

        return repl_definition

    def post_process(self, repl_definition, repl_id, detached=False):
        if detached:
            self.nvim.current.tabpage.vars[
                "iron_{}_repl_id".format(repl_definition['ft'])
            ] = repl_id
        else:
            repl_definition = self.bind_repl(repl_definition, repl_id)

        self.call_hooks(repl_definition)

        return repl_definition


    def build_from_template(self, template, command, with_placement):
        repl_definition = {
            'ft': template['language'],
            'fns': {},
            'mapped_keys': [],
            'instances': {},
        }
        if 'multiline' in template:
            repl_definition['multiline'] = template['multiline']

        return self.set_mappings(template, repl_definition)

    def open_repl(self, template, **kwargs):
        ft = template['language']
        pwd = self.get_pwd()
        command = kwargs.get('command', template['command'])
        with_placement = kwargs.get('with_placement', True)
        detached = kwargs.get('detached', False)
        bang = kwargs.get('bang', False)
        bufwinnr = self.nvim.funcs.bufwinnr
        bufname = self.nvim.funcs.bufname

        def create_new_repl():
            repl_id = self.termopen(command, with_placement)
            repl_definition = self.__repl.get(ft, self.build_from_template(
                template, command, with_placement
            ))

            self.__repl[ft] = self.post_process(
                repl_definition, repl_id, detached
            )

        if not self.has_repl_defined(ft):
            logger.debug("No REPL started for ft {}. Starting".format(ft))
            create_new_repl()
        elif not pwd in self.__repl[ft]['instances']:
            logger.debug("No REPL for ft {} on path '{}'. Creating".format(
                ft, pwd
            ))
            create_new_repl()

        else:
            buf_id = self.__repl[ft]['instances'][pwd]['buf_id']
            toggleable_buffer(
                self.nvim, buf_id, create_new_repl,
                orientation=self.get_variable(
                    'iron_repl_open_cmd', 'botright spl'
                ))

        logger.debug("Done! REPL for {} running on {}".format(ft, pwd))
