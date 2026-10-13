"""REPL startup: runs iron_image inside a REPL when it starts.

One module per REPL kind. iron (lua/iron/image/lang/python.lua) picks the
module from the REPL command and loads it the way that REPL allows:

    python    startup/python.py     run as PYTHONSTARTUP
    ipython   startup/ipython.py    loaded with --ext=iron_image.startup.ipython

A startup module must call ``iron_image._loader.activate(<repl>)`` once, as
early as possible, so integrations install when their library is imported.
It may also handle how that REPL displays output. Anything about a specific
library belongs in ``integrations/``.

Adding a REPL: add ``startup/<repl>.py``, add its name to ``REPLS`` and make
lang/python.lua recognize the REPL and load the module.
"""

REPLS = ("python", "ipython")
