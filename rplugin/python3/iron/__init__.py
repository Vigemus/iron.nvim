# encoding:utf-8
""" iron.nvim (Interactive Repls Over Neovim).

`iron` is a plugin that allows better interactions with interactive repls
using neovim's job-control and terminal.

Currently it keeps track of a single repl instance per filetype.
"""
import logging
import neovim
from iron.base import BaseIron

log = logging.getLogger(__name__)
log.setLevel(logging.DEBUG)


@neovim.plugin
class Iron(BaseIron):

    def __init__(self, nvim):
        super().__init__(nvim)

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
        self.set_repl_id(ft, repl_id)


        return repl_id

    def sanitize_multiline(self, data, repl):
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

        return self.send_to_repl([self.register('s')])

    @neovim.function("IronSend")
    def send_to_repl(self, args):
        repl = self.get_repl(args[1]) if len(args) > 1 else None
        repl = repl or self.get_current_repl()

        if not repl:
            return None

        log.info("Sending data to repl -> {}".format(repl))

        if 'multiline' in repl:
            log.info("Multiline statement allowed - wrapping")
            data, extra = self.sanitize_multiline(args[0], repl)
        else:
            log.info("Plain string - no multiline")
            data = "{}\n".format(args[0])
            extra = None

        self.send_data(data, repl)

        if extra is not None:
            self.send_data(extra, repl)
