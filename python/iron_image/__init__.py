"""Helper iron loads into Python REPLs that have ``image`` enabled.

Each PNG is sent to iron as base64 chunks in an OSC sequence:

    ESC ] 51;iron-image;<id>;<cols>;<rows>;<part>;<more>;<chunk> BEL

iron receives them through Neovim's TermRequest event, keeps a copy and
draws the image in the host terminal. The REPL then prints the cells the
image covers, so it scrolls with the rest of the output.

Only the standard library is needed. The limits in this package must match
lua/iron/image/init.lua.
"""

from ._core import display, show
from .integrations.ipython import (
    load_ipython_extension,
    unload_ipython_extension,
)

__all__ = [
    "display",
    "load_ipython_extension",
    "show",
    "unload_ipython_extension",
]
