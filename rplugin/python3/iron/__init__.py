# encoding:utf-8
""" iron.nvim (Interactive Repls Over Neovim).  """
import logging
import neovim
import os
from iron.base import BaseIron

logger = logging.getLogger(__name__)

if 'NVIM_IRON_DEBUG_FILE' in os.environ:
    logfile = os.environ['NVIM_IRON_DEBUG_FILE'].strip()
    logger.addHandler(logging.FileHandler(logfile, 'w'))

logger.level = logging.DEBUG


@neovim.plugin
class Iron(BaseIron):

    def __init__(self, nvim):
        super().__init__(nvim)

    # Actual Fns
    def sanitize_multiline(self, data, repl):
        multiline = repl['multiline']
        if "\n" in data and repl:
            if len(multiline) == 4:
                (pre, post, extra, nline) = multiline
            elif len(multiline) == 3:
                (pre, post, extra) = multiline
                nline = '\n'
            else:
                (pre, post) = multiline
                nline = '\n'
                extra = None

            logger.info("Multinine string supplied.")
            return ("{}{}{}".format(pre, data.replace('\n', nline), post), extra)

        logger.info("String was not multiline. Continuing")
        return ("{}\n".format(data), None)

    def get_or_prompt_ft(self):
        ft = self.get_ft()
        return self.has_repl_template(ft) and ft or self.prompt("repl type")

    @neovim.command("IronFocus", sync=True)
    def focus_on_repl(self):
        try:
            ft = self.get_or_prompt_ft()
            repl =  self.get_repl(ft)
            if repl is None:
                logger.warning("No repl open for ft: {}".format(ft))
                return

            pwd = self.get_pwd()
            buf_id = repl['instances'][pwd]['buf_id']
            nr = self.nvim.funcs.bufwinnr(buf_id)
            self.call_cmd('{}wincmd w'.format(nr))
        except Exception as e:
            logger.warning("Error focusing: {}".format(e))

    @neovim.command("IronPromptCommand", sync=True)
    def prompt_command(self):
        try:
            command = self.prompt("command")
            template = self.get_template_for_ft(self.get_or_prompt_ft())
        except:
            logger.warning("User aborted.")
        else:
            template['command'] = command
            self.open_repl(template, command=command)

    @neovim.command("IronPromptRepl", sync=True)
    def prompt_query(self):
        try:
            ft = self.prompt("repl type")
        except:
            logger.warning("User aborted.")
        else:
            self.iron_repl([ft])

    @neovim.command("IronRepl", bang=True, sync=True)
    def create_repl(self, bang):
        ft = self.get_ft()
        self.iron_repl([ft], bang=bang)

    @neovim.command("IronDumpReplDefinition")
    def dump_repl_dict(self):
        super().dump_repl_dict()

    @neovim.command("IronClearReplDefinition")
    def clear_repl_definition(self):
        try:
            self.clear_repl_for_ft(self.get_or_prompt_ft())
        except:
            logger.warning("User aborted.")

    @neovim.function("IronStartRepl", sync=True)
    def iron_repl(self, args, bang=False):
        ft = args[0]
        kwargs = {
            "with_placement": bool(args[1]) if len(args) > 1 else True,
            "detached": bool(args[2]) if len(args) > 2 else False,
            "bang": bang
        }

        template = self.get_template_for_ft(ft)

        if not ft:
            self.call_cmd("echo 'Closing without a file type'")
            return
        elif not template:
            self.call_cmd("echo 'Unable to find repl for {}'".format(ft))
            return

        self.open_repl(template, **kwargs)

    @neovim.function("IronSendSpecial")
    def mapping_send(self, args):
        fn = self.get_current_bindings().get(args[0])
        if fn:
            fn(self)

    @neovim.function("IronSendMotion", range=True)
    def send_motion_to_repl(self, args, rng=None):
        logger.debug("Supplied data: {}".format(", ".join(args)))
        cur_buf = self.nvim.current.buffer

        if not 'iron_cursor_pos' in cur_buf.vars:
            # Probably repeating, so setting the position manually
            cur_buf.vars['iron_cursor_pos'] = self.call('winsaveview')

        if args[0] == 'visual':
            init = cur_buf.mark('<')
            end = cur_buf.mark('>')
        else:
            init = cur_buf.mark('[')
            end = cur_buf.mark(']')

        end[1] += 1

        text = cur_buf[init[0]-1:end[0]]

        logger.debug("Gathered: {} - {}: {}".format(
            init, end, "\n".join(text)))

        if args[0] != 'line':
            if init[0] == end[0]:
                text[0] = text[0][init[1]:end[1]]
            else:
                text[0] = text[0][init[1]:]
                text[-1] = text[-1][:end[1]]

            logger.debug("Stripped: {}".format("\n".join(text)))

        self.call('winrestview', cur_buf.vars['iron_cursor_pos'])
        del cur_buf.vars['iron_cursor_pos']

        return self.send_to_repl(["\n".join(text)])

    @neovim.function("IronSend")
    def send_to_repl(self, args):
        logger.debug("Supplied data: {}".format(", ".join(args)))
        repl = (
            self.get_repl(args[1])
            if len(args) > 1
            else None
            or self.get_repl(self.get_ft())
        )

        logger.info("Sending data to repl -> {}".format(repl))

        if 'multiline' in repl:
            logger.info("Multiline statement allowed - wrapping")
            data, extra = self.sanitize_multiline(args[0], repl)
        else:
            logger.info("Plain string - no multiline")
            data = "{}\n".format(args[0])
            extra = None

        self.send_data(data, repl)

        if extra is not None:
            self.send_data(extra, repl)
