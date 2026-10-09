"""Inline PNGs for Iron's Python REPL. The transport needs only the stdlib.

Like pyrepl.nvim, images use Kitty virtual placements and Unicode placeholders.
Iron forwards bounded OSC messages through Neovim's TermRequest event, avoiding
an RPC client, temporary image files, or a Kitty executable.
"""

import base64
import itertools
import os
import shutil
import sys
import threading

PLACEHOLDER = "\U0010eeee"
# First 20 entries of Kitty's row/column diacritics table.
DIACRITICS = (
    "\u0305\u030d\u030e\u0310\u0312\u033d\u033e\u033f\u0346\u034a"
    "\u034b\u034c\u0350\u0351\u0352\u0357\u035b\u0363\u0364\u0365"
)
_ids = itertools.count(1)
_lock = threading.RLock()
_extensions = {}
MAX_PNG_BYTES = 12 * 1024 * 1024


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
        raise TypeError(
            "iron: display expects PNG bytes, a PNG path, or _repr_png_"
        )
    if not isinstance(png, bytes):
        raise ValueError("iron: object did not provide PNG data")
    if len(png) > MAX_PNG_BYTES:
        raise ValueError("iron: PNG exceeds the 12 MiB image limit")
    if (
        len(png) < 24
        or png[:8] != b"\x89PNG\r\n\x1a\n"
        or png[12:16] != b"IHDR"
    ):
        raise ValueError("iron: expected PNG data")
    if not int.from_bytes(png[16:20], "big") or not int.from_bytes(
        png[20:24], "big"
    ):
        raise ValueError("iron: PNG dimensions must be positive")
    namespace = int(os.environ.get("IRON_IMAGE_NAMESPACE", "0"))
    if not 128 <= namespace <= 255:
        raise RuntimeError(
            "iron: enable image = true in the Python REPL definition"
        )
    terminal = shutil.get_terminal_size((80, 24))
    # Use the reference IPython renderer's fixed bounding box.
    cols = max(1, min(terminal.columns - 3, 80))
    rows = max(1, min(terminal.lines // 2, 20))
    payload = base64.b64encode(png).decode("ascii")
    with _lock:
        serial = next(_ids)
        if serial >= 65536:
            raise RuntimeError(
                "iron: image ID space exhausted; restart the REPL"
            )
        image_id = namespace * 65536 + serial
        out = sys.stdout
        # PNG upload and placement are forwarded by Neovim to the outer terminal.
        for part, offset in enumerate(range(0, len(payload), 4096)):
            chunk = payload[offset : offset + 4096]
            more = int(offset + len(chunk) < len(payload))
            out.write(
                f"\x1b]51;iron-image;{image_id};{cols};{rows};{part};{more};{chunk}\x07"
            )
        color = f"\x1b[38;2;{image_id >> 16};{(image_id >> 8) & 255};{image_id & 255}m"
        padding = " " * max(0, (terminal.columns - cols) // 2)
        for row in range(rows):
            # Explicit row AND column-zero markers make redraw/clipping unambiguous.
            cells = (
                PLACEHOLDER
                + DIACRITICS[row]
                + DIACRITICS[0]
                + PLACEHOLDER * (cols - 1)
            )
            out.write("\r" + padding + color + cells + "\x1b[39m\r\n")
        out.flush()


def load_ipython_extension(shell):
    """Render IPython PNG display data while preserving its normal text output."""
    if id(shell) in _extensions:
        return
    original = shell.display_pub.publish
    active_types = list(shell.display_formatter.active_types)
    shell.display_formatter.active_types = list(
        dict.fromkeys(active_types + ["image/png"])
    )

    def publish(data, metadata=None, **kwargs):
        if "image/png" in data:
            try:
                png = data["image/png"]
                display(
                    base64.b64decode(png, validate=True)
                    if isinstance(png, str)
                    else png
                )
                return
            except (ValueError, TypeError, RuntimeError) as error:
                print(str(error), file=sys.stderr)
        return original(data, metadata=metadata, **kwargs)

    shell.display_pub.publish = publish
    _extensions[id(shell)] = (original, active_types)


def unload_ipython_extension(shell):
    previous = _extensions.pop(id(shell), None)
    if previous:
        shell.display_pub.publish, shell.display_formatter.active_types = (
            previous
        )
