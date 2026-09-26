"""Inline PNGs for Iron's Python REPL. The transport needs only the stdlib.

Like pyrepl.nvim, images use Kitty virtual placements and Unicode placeholders.
Iron forwards bounded OSC messages through Neovim's TermRequest event, avoiding
an RPC client, a Jupyter kernel, temporary image files, or a Kitty executable.
"""

import base64
import itertools
import math
import os
import shutil
import struct
import sys
import threading

PLACEHOLDER = "\U0010eeee"
# Kitty's stable row/column table: first 64 entries, in protocol order.
DIACRITICS = tuple(chr(int(value, 16)) for value in (
    "0305 030D 030E 0310 0312 033D 033E 033F 0346 034A 034B 034C 0350 0351 0352 0357 "
    "035B 0363 0364 0365 0366 0367 0368 0369 036A 036B 036C 036D 036E 036F 0483 0484 "
    "0485 0486 0487 0592 0593 0594 0595 0597 0598 0599 059C 059D 059E 059F 05A0 05A1 "
    "05A8 05A9 05AB 05AC 05AF 05C4 0610 0611 0612 0613 0614 0615 0616 0617 0657 0658"
).split())
_ids = itertools.count(1)
_lock = threading.RLock()
_extensions = {}
MAX_PNG_BYTES = 12 * 1024 * 1024


def _dimensions(png):
    if len(png) < 24 or png[:8] != b"\x89PNG\r\n\x1a\n" or png[12:16] != b"IHDR":
        raise ValueError("iron: expected PNG data")
    width, height = struct.unpack(">II", png[16:24])
    if not width or not height:
        raise ValueError("iron: PNG dimensions must be positive")
    return width, height


def display(image):
    """Display a PNG path, PNG bytes, or an object implementing _repr_png_."""
    if isinstance(image, (str, os.PathLike)):
        with open(image, "rb") as source:
            png = source.read(MAX_PNG_BYTES + 1)
    elif isinstance(image, (bytes, bytearray)):
        png = bytes(image)
    elif hasattr(image, "_repr_png_"):
        png = image._repr_png_()
        if isinstance(png, tuple):
            png = png[0]
        if isinstance(png, str):
            png = base64.b64decode(png, validate=True)
    else:
        raise TypeError("iron: display expects PNG bytes, a PNG path, or _repr_png_")
    if not isinstance(png, bytes):
        raise ValueError("iron: object did not provide PNG data")
    if len(png) > MAX_PNG_BYTES:
        raise ValueError("iron: PNG exceeds the 12 MiB image limit")
    width, height = _dimensions(png)
    namespace = int(os.environ.get("IRON_IMAGE_NAMESPACE", "0"))
    if not 128 <= namespace <= 255:
        raise RuntimeError("iron: enable image = true in the Python REPL definition")
    terminal = shutil.get_terminal_size((80, 24))
    cols = max(1, min(256, int(terminal.columns * 0.9)))
    rows = max(1, math.ceil(cols * height / width / 2))
    max_rows = max(1, min(len(DIACRITICS), terminal.lines - 2))
    if rows > max_rows:
        rows = max_rows
        cols = max(1, min(cols, int(rows * 2 * width / height)))
    payload = base64.b64encode(png).decode("ascii")
    with _lock:
        serial = next(_ids)
        if serial >= 65536:
            raise RuntimeError("iron: image ID space exhausted; restart the REPL")
        image_id = namespace * 65536 + serial
        out = sys.stdout
        # PNG upload and placement are forwarded by Neovim to the outer terminal.
        for part, offset in enumerate(range(0, len(payload), 4096)):
            chunk = payload[offset:offset + 4096]
            more = int(offset + len(chunk) < len(payload))
            out.write(f"\x1b]51;iron-image;{image_id};{cols};{rows};{part};{more};{chunk}\x07")
        color = f"\x1b[38;2;{image_id >> 16};{(image_id >> 8) & 255};{image_id & 255}m"
        padding = " " * max(0, (terminal.columns - cols) // 2)
        for row in range(rows):
            # Explicit row AND column-zero markers make redraw/clipping unambiguous.
            cells = PLACEHOLDER + DIACRITICS[row] + DIACRITICS[0] + PLACEHOLDER * (cols - 1)
            out.write("\r" + padding + color + cells + "\x1b[39m\r\n")
        out.flush()


def load_ipython_extension(shell):
    """Render IPython PNG display data while preserving its normal text output."""
    if id(shell) in _extensions:
        return
    original = shell.display_pub.publish
    active_types = list(shell.display_formatter.active_types)
    shell.display_formatter.active_types = list(dict.fromkeys(active_types + ["image/png"]))

    def publish(data, metadata=None, **kwargs):
        if "image/png" in data:
            try:
                png = data["image/png"]
                display(base64.b64decode(png, validate=True) if isinstance(png, str) else png)
                return
            except (ValueError, TypeError, RuntimeError) as error:
                print(str(error), file=sys.stderr)
        return original(data, metadata=metadata, **kwargs)

    shell.display_pub.publish = publish
    _extensions[id(shell)] = (original, active_types)


def unload_ipython_extension(shell):
    previous = _extensions.pop(id(shell), None)
    if previous:
        shell.display_pub.publish, shell.display_formatter.active_types = previous
