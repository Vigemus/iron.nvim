"""Shows PNGs inline: assigns ids, sizes the box, sends and draws."""

import itertools
import os
import shutil
import sys
import threading

from ._convert import Image, check_png, to_png
from ._kitty import placeholders
from ._transport import send

MAX_COLS = 80
MAX_ROWS = 20
NAMESPACES = range(128, 256)
IDS_PER_NAMESPACE = 65536

_serials = itertools.count(1)
_lock = threading.Lock()


def show(png: bytes) -> None:
    """Show PNG bytes inline."""
    check_png(png)
    namespace = _namespace()
    terminal = shutil.get_terminal_size((80, 24))
    # Keep a small right margin so the last cell never touches the edge.
    cols = max(1, min(terminal.columns - 3, MAX_COLS))
    rows = max(1, min(terminal.lines // 2, MAX_ROWS))
    indent = " " * max(0, (terminal.columns - cols) // 2)

    with _lock:
        image_id = _next_id(namespace)
        send(image_id, cols, rows, png)
        placeholders(image_id, cols, rows, indent)
        sys.stdout.flush()


def display(image: Image) -> None:
    """Show a PNG path, PNG bytes or an object with ``_repr_png_`` inline."""
    show(to_png(image))


def _namespace() -> int:
    """This REPL's image id namespace, assigned by iron."""
    try:
        namespace = int(os.environ.get("IRON_IMAGE_NAMESPACE", ""))
    except ValueError:
        namespace = 0
    if namespace not in NAMESPACES:
        raise RuntimeError(
            "iron: enable image = true in the Python REPL definition"
        )
    return namespace


def _next_id(namespace: int) -> int:
    serial = next(_serials)
    if serial >= IDS_PER_NAMESPACE:
        raise RuntimeError("iron: image ID space exhausted; restart the REPL")
    return namespace * IDS_PER_NAMESPACE + serial
