"""Helper iron loads into Python REPLs that have ``image`` enabled.

Each PNG is sent to iron as base64 chunks in an OSC sequence:

    ESC ] 51;iron-image;<id>;<cols>;<rows>;<part>;<more>;<chunk> BEL

iron receives them through Neovim's TermRequest event, keeps a copy and
draws the image in the host terminal. The REPL then prints the cells the
image covers, so it scrolls with the rest of the output.

Only the standard library is needed. The limits below must match
lua/iron/image/init.lua.
"""

import base64
import itertools
import os
import shutil
import sys
import threading
from collections.abc import Callable
from typing import Any, Protocol, TypeAlias

CHUNK_SIZE = 4096
MAX_COLS = 80
MAX_ROWS = 20
MAX_PNG_BYTES = 12 * 1024 * 1024
NAMESPACES = range(128, 256)
IDS_PER_NAMESPACE = 65536
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

# Kitty Unicode placeholder and the first MAX_ROWS row/column diacritics.
PLACEHOLDER = "\U0010eeee"
DIACRITICS = "̅̍̎̐̒̽̾̿͆͊͋͌͐͑͒͗͛ͣͤͥ"


class SupportsReprPng(Protocol):
    def _repr_png_(self) -> Any: ...


Image: TypeAlias = str | os.PathLike[str] | bytes | bytearray | SupportsReprPng

_serials = itertools.count(1)
_lock = threading.Lock()
_extensions: dict[int, tuple[Callable[..., Any], list[str]]] = {}


def display(image: Image) -> None:
    """Show a PNG path, PNG bytes or an object with ``_repr_png_`` inline."""
    png = _to_png(image)
    _check_png(png)
    namespace = _namespace()
    terminal = shutil.get_terminal_size((80, 24))
    # Keep a small right margin so the last cell never touches the edge.
    cols = max(1, min(terminal.columns - 3, MAX_COLS))
    rows = max(1, min(terminal.lines // 2, MAX_ROWS))
    indent = " " * max(0, (terminal.columns - cols) // 2)

    with _lock:
        image_id = _next_id(namespace)
        _send(image_id, cols, rows, png)
        _kitty_placeholders(image_id, cols, rows, indent)
        sys.stdout.flush()


def _to_png(image: Image) -> bytes:
    if isinstance(image, (str, os.PathLike)):
        with open(image, "rb") as source:
            return source.read(MAX_PNG_BYTES + 1)
    if isinstance(image, (bytes, bytearray)):
        return bytes(image)
    if hasattr(image, "_repr_png_"):
        data = image._repr_png_()
        if isinstance(data, tuple):
            data = data[0]
        if isinstance(data, (str, bytes)):
            return _from_mime(data)
        raise ValueError("iron: object did not provide PNG data")
    raise TypeError(
        "iron: display expects PNG bytes, a PNG path, or _repr_png_"
    )


def _from_mime(data: str | bytes) -> bytes:
    """PNG bytes from IPython display data, which may be base64 text."""
    if isinstance(data, str):
        return base64.b64decode(data, validate=True)
    return data


def _check_png(png: bytes) -> None:
    if len(png) > MAX_PNG_BYTES:
        raise ValueError("iron: PNG exceeds the 12 MiB image limit")
    if not png.startswith(PNG_SIGNATURE) or png[12:16] != b"IHDR":
        raise ValueError("iron: expected PNG data")


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


def _send(image_id: int, cols: int, rows: int, png: bytes) -> None:
    """Sends the PNG to iron in CHUNK_SIZE pieces."""
    payload = base64.b64encode(png).decode("ascii")
    for part, offset in enumerate(range(0, len(payload), CHUNK_SIZE)):
        chunk = payload[offset : offset + CHUNK_SIZE]
        more = int(offset + CHUNK_SIZE < len(payload))
        sys.stdout.write(
            f"\x1b]51;iron-image;{image_id};{cols};{rows};{part};{more};{chunk}\x07"
        )


def _kitty_placeholders(
    image_id: int, cols: int, rows: int, indent: str
) -> None:
    """Prints the cells kitty draws the image over.

    The image id travels in the 24-bit foreground color and each row is
    marked with its own diacritic.
    """
    red, green, blue = image_id >> 16, (image_id >> 8) & 255, image_id & 255
    color = f"\x1b[38;2;{red};{green};{blue}m"
    for row in range(rows):
        cells = (
            PLACEHOLDER
            + DIACRITICS[row]
            + DIACRITICS[0]
            + PLACEHOLDER * (cols - 1)
        )
        sys.stdout.write(f"\r{indent}{color}{cells}\x1b[39m\r\n")


def load_ipython_extension(shell: Any) -> None:
    """Shows IPython PNG display data inline; other data passes through."""
    if id(shell) in _extensions:
        return
    original = shell.display_pub.publish
    active_types = list(shell.display_formatter.active_types)
    shell.display_formatter.active_types = list(
        dict.fromkeys([*active_types, "image/png"])
    )

    def publish(
        data: dict[str, Any], metadata: Any = None, **kwargs: Any
    ) -> Any:
        if "image/png" in data:
            try:
                display(_from_mime(data["image/png"]))
                return None
            except (ValueError, TypeError, RuntimeError) as error:
                print(error, file=sys.stderr)
        return original(data, metadata=metadata, **kwargs)

    shell.display_pub.publish = publish
    _extensions[id(shell)] = (original, active_types)


def unload_ipython_extension(shell: Any) -> None:
    previous = _extensions.pop(id(shell), None)
    if previous:
        shell.display_pub.publish, shell.display_formatter.active_types = (
            previous
        )
