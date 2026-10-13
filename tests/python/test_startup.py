"""Tests for iron_image.startup: the python and ipython REPL startups.

Each test starts a real REPL in a fresh process and feeds it input on stdin.
"""

from pathlib import Path

import pytest
from conftest import Iron

# A 1x1 PNG and an object IPython can render with it
PNG_OBJECT = """
import struct, zlib
def _chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))
PNG = (b"\\x89PNG\\r\\n\\x1a\\n"
    + _chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
    + _chunk(b"IDAT", zlib.compress(b"\\0\\0\\0\\0"))
    + _chunk(b"IEND", b""))
class Picture:
    def _repr_png_(self):
        return PNG
"""

HOOKED = (
    "print('hooked', any(type(f).__name__ == '_Finder' for f in "
    "__import__('sys').meta_path))\n"
)


def test_python_activates_loader_and_leaves_no_names(iron: Iron):
    result = iron.repl(
        HOOKED + "print('names', [n for n in dir() if 'iron' in n])\n"
    )
    assert "hooked True" in result.out, result.err
    assert "names []" in result.out, result.err


def test_python_runs_user_startup_in_repl_namespace(
    iron: Iron, tmp_path: Path
):
    user = tmp_path / "startup.py"
    user.write_text("USER_VALUE = 42\nprint('user startup ran')\n")
    result = iron.repl(
        HOOKED + "print('value', USER_VALUE)\n",
        IRON_PYTHONSTARTUP=str(user),
    )
    assert "user startup ran" in result.out, result.err
    assert "hooked True" in result.out, result.err
    assert "value 42" in result.out, result.err


def test_python_failing_user_startup_is_reported_and_repl_continues(
    iron: Iron, tmp_path: Path
):
    user = tmp_path / "startup.py"
    user.write_text("raise ValueError('user startup broke')\n")
    result = iron.repl(
        HOOKED + "print('still here')\n",
        IRON_PYTHONSTARTUP=str(user),
    )
    assert "ValueError: user startup broke" in result.err
    assert "hooked True" in result.out, result.err
    assert "still here" in result.out, result.err


@pytest.fixture
def ipython(iron: Iron) -> Iron:
    pytest.importorskip("IPython")
    return iron


def test_ipython_activates_loader(ipython: Iron):
    result = ipython.ipython(HOOKED)
    assert "hooked True" in result.out, result.err


def test_ipython_display_shows_png_inline(ipython: Iron):
    result = ipython.ipython(PNG_OBJECT + "display(Picture())\n")
    assert result.images == 1, result.err


def test_ipython_bare_result_shows_png_inline(ipython: Iron):
    result = ipython.ipython(PNG_OBJECT + "Picture()\n")
    assert result.images == 1, result.err


def test_ipython_text_output_unchanged(ipython: Iron):
    result = ipython.ipython("6 * 7\n")
    assert "42" in result.out, result.err
    assert "iron-image" not in result.out
