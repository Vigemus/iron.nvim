"""ipython startup, loaded with --ext=iron_image.startup.ipython.

Starts the loader, and shows PNG output inline through IPython's
``mime_renderers`` setting: ``display(x)``, or ``x`` alone on the last line,
for anything IPython can render as a PNG.
"""

import sys
from typing import Any

from .._convert import from_mime
from .._core import show
from .._loader import activate


def load_ipython_extension(shell: Any) -> None:
    activate("ipython")
    renderers = getattr(shell, "mime_renderers", {})
    shell.mime_renderers = {**renderers, "image/png": _show_png}
    # The terminal only computes the formats it is asked for
    active_types = list(shell.display_formatter.active_types)
    if "image/png" not in active_types:
        shell.display_formatter.active_types = [*active_types, "image/png"]


def _show_png(data: str | bytes, metadata: Any) -> None:
    try:
        show(from_mime(data))
    except (ValueError, TypeError, RuntimeError) as error:
        print(error, file=sys.stderr)
