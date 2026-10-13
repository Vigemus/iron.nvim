"""Pillow: img.show() draws the image inline instead of opening an external
viewer.

Registers a viewer with Pillow's ImageShow, ahead of the system viewers.
(In ipython, ``display(img)`` and a bare ``img`` are shown by
``startup/ipython.py``, since Pillow images already offer IPython a PNG.)
"""

import io
import sys
from typing import Any

from PIL import Image, ImageShow

from .._core import show as show_png

# Modes Pillow can write to PNG as they are; others are converted first
_PNG_MODES = {"1", "L", "LA", "I", "I;16", "P", "RGB", "RGBA"}


def install_python() -> None:
    _register_viewer()


def install_ipython() -> None:
    _register_viewer()


def _register_viewer() -> None:
    # Order 0 puts it before the system viewers
    ImageShow.register(_InlineViewer(), 0)


class _InlineViewer(ImageShow.Viewer):
    def show(self, image: Image.Image, **options: Any) -> int:
        try:
            show_png(_to_png(image))
        except (ValueError, TypeError, RuntimeError, OSError) as error:
            # Not shown: Pillow moves on to the next (external) viewer
            print(error, file=sys.stderr)
            return 0
        return 1


def _to_png(image: Image.Image) -> bytes:
    if image.mode not in _PNG_MODES:
        has_alpha = "A" in image.getbands()
        image = image.convert("RGBA" if has_alpha else "RGB")
    output = io.BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()
