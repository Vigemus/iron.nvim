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
            if len(multiline) == 3:
                (pre, post, extra) = multiline
            else:
                (pre, post) = multiline
                extra = None

            logger.info("Multinine string supplied.")
            return ("{}{}{}".format(pre, data, post), extra)

        logger.info("String was not multiline. Continuing")
        return ("{}\n".format(data), None)

    def get_or_prompt_ft(self):
        ft = self.get_ft()
        return self.has_repl_template(ft) and ft or self.prompt("repl type")

    @neovim.command("IronPromptCommand")
    def prompt_command(self):
        try:
            command = self.prompt("command")
            template = self.get_template_for_ft(self.get_or_prompt_ft())
        except:
            logger.warning("User aborted.")
        else:
            template['command'] = command
            self.open_repl(template, command=command)

    @neovim.command("IronPromptRepl")
    def prompt_query(self):
        try:
            ft = self.prompt("repl type")
        except:
            logger.warning("User aborted.")
        else:
            self.iron_repl([ft])

    @neovim.command("IronRepl", bang=True)
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

    @neovim.function("IronStartRepl")
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
        if args[0] == 'line':
            self.call_cmd("""normal! '[V']"sy""")
        if args[0] == 'visual':
            self.call_cmd("""normal! `<v`>"sy""")
        else:
            self.call_cmd("""normal! `[v`]"sy""")

        return self.send_to_repl([self.register('s')])

    @neovim.function("IronSend")
    def send_to_repl(self, args):
        repl = (
            self.get_repl(args[1])
            if len(args) > 1
            else None
            or self.get_repl(self.get_ft())
        )

        logger.debug("Supplied data: {}".format(args[0]))
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
