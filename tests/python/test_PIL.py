"""Tests for iron_image.integrations.PIL, installed by the loader."""

import pytest
from conftest import Iron

pytest.importorskip("PIL")

# Keep only our viewer plus a stand-in for the system ones, so no real
# image viewer can open during the tests
PRELUDE = """
from iron_image import _loader
_loader.activate("python")
from PIL import Image, ImageShow

class _Fallback(ImageShow.Viewer):
    def show(self, image, **options):
        print("fallback viewer")
        return 1

ImageShow._viewers[:] = [
    v for v in ImageShow._viewers if type(v).__name__ == "_InlineViewer"
]
ImageShow.register(_Fallback())
"""


def test_show_draws_inline(iron: Iron):
    result = iron.python(PRELUDE + 'Image.new("RGB", (8, 4), "red").show()\n')
    assert result.code == 0, result.err
    assert result.images == 1
    assert "fallback viewer" not in result.out


def test_modes_png_cannot_store_are_converted(iron: Iron):
    result = iron.python(
        PRELUDE
        + """
Image.new("CMYK", (8, 4)).show()
Image.new("F", (8, 4)).show()
"""
    )
    assert result.code == 0, result.err
    assert result.images == 2


def test_failure_warns_and_falls_back_to_other_viewers(iron: Iron):
    result = iron.python(
        PRELUDE + 'Image.new("RGB", (8, 4)).show()\n',
        IRON_IMAGE_NAMESPACE=None,
    )
    assert result.code == 0, result.err
    assert "fallback viewer" in result.out
    assert "enable image = true" in result.err
