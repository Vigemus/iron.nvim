"""Shows PNGs inline: assigns ids, sizes the box, sends and draws."""

import itertools
import os
import shutil
import sys
import threading
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from ._convert import Image, check_png, to_png
from ._kitty import placeholders
from ._transport import send

MAX_COLS = 80
MAX_ROWS = 20
NAMESPACES = range(128, 256)
IDS_PER_NAMESPACE = 65536

_serials = itertools.count(1)
_lock = threading.Lock()


@dataclass(frozen=True)
class InteractiveFile:
    """An interactive version of an image, opened by :IronImageOpen.

    ``write`` saves it to the path it is given, ``<id><suffix>`` in the
    REPL's image dir, so iron can find it next to the PNG.
    """

    suffix: str
    write: Callable[[Path], None]


def show(png: bytes, interactive: InteractiveFile | None = None) -> None:
    """Show PNG bytes inline, optionally with an interactive version."""
    check_png(png)
    namespace = _namespace()
    terminal = shutil.get_terminal_size((80, 24))
    # Keep a small right margin so the last cell never touches the edge.
    cols = max(1, min(terminal.columns - 3, MAX_COLS))
    rows = max(1, min(terminal.lines // 2, MAX_ROWS))
    indent = " " * max(0, (terminal.columns - cols) // 2)

    with _lock:
        image_id = _next_id(namespace)
        # Written before the PNG is sent, so it exists once iron has the image
        if interactive is not None:
            _write_interactive(image_id, interactive)
        send(image_id, cols, rows, png)
        placeholders(image_id, cols, rows, indent)
        sys.stdout.flush()


def display(image: Image) -> None:
    """Show a PNG path, PNG bytes or an object with ``_repr_png_`` inline."""
    show(to_png(image))


def _write_interactive(image_id: int, interactive: InteractiveFile) -> None:
    """Saves the interactive file; on failure only the PNG is shown."""
    directory = os.environ.get("IRON_IMAGE_DIR")
    if not directory:
        return
    path = Path(directory) / f"{image_id}{interactive.suffix}"
    try:
        interactive.write(path)
        # iron opens interactive files with the Python running this REPL
        (Path(directory) / "python").write_text(sys.executable)
    except Exception as error:
        path.unlink(missing_ok=True)
        print(f"iron: no interactive version: {error}", file=sys.stderr)


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
