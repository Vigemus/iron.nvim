"""Tests for iron_image.startup: the python and ipython REPL startups.

Each test starts a real REPL in a fresh process and feeds it input on stdin.
"""

import importlib.util
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

PYTHON_DIR = Path(__file__).resolve().parents[2] / "python"
STARTUP = PYTHON_DIR / "iron_image" / "startup" / "python.py"

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


def env(**extra: str) -> dict[str, str]:
    base = {k: v for k, v in os.environ.items() if not k.startswith("IRON_")}
    base.pop("PYTHONSTARTUP", None)
    return {
        **base,
        "PYTHONPATH": str(PYTHON_DIR),
        "IRON_IMAGE_NAMESPACE": "130",
        **extra,
    }


def run_python(stdin: str, **extra: str) -> tuple[str, str]:
    result = subprocess.run(
        [sys.executable, "-i", "-q"],
        input=textwrap.dedent(stdin),
        capture_output=True,
        text=True,
        env=env(PYTHONSTARTUP=str(STARTUP), PYTHON_BASIC_REPL="1", **extra),
        timeout=60,
    )
    return result.stdout, result.stderr


def run_ipython(stdin: str) -> tuple[str, str]:
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "IPython",
            "--no-banner",
            "--colors=nocolor",
            "--ext=iron_image.startup.ipython",
        ],
        input=textwrap.dedent(stdin),
        capture_output=True,
        text=True,
        env=env(),
        timeout=60,
    )
    return result.stdout, result.stderr


HOOKED = (
    "print('hooked', any(type(f).__name__ == '_Finder' for f in "
    "__import__('sys').meta_path))\n"
)


class PythonStartupTest(unittest.TestCase):
    def test_activates_loader_and_leaves_no_names(self):
        out, err = run_python(
            HOOKED + "print('names', [n for n in dir() if 'iron' in n])\n"
        )
        self.assertIn("hooked True", out, err)
        self.assertIn("names []", out, err)

    def test_runs_user_startup_in_repl_namespace(self):
        with tempfile.TemporaryDirectory() as tmp:
            user = Path(tmp) / "startup.py"
            user.write_text("USER_VALUE = 42\nprint('user startup ran')\n")
            out, err = run_python(
                HOOKED + "print('value', USER_VALUE)\n",
                IRON_PYTHONSTARTUP=str(user),
            )
        self.assertIn("user startup ran", out, err)
        self.assertIn("hooked True", out, err)
        self.assertIn("value 42", out, err)

    def test_failing_user_startup_is_reported_and_repl_continues(self):
        with tempfile.TemporaryDirectory() as tmp:
            user = Path(tmp) / "startup.py"
            user.write_text("raise ValueError('user startup broke')\n")
            out, err = run_python(
                HOOKED + "print('still here')\n",
                IRON_PYTHONSTARTUP=str(user),
            )
        self.assertIn("ValueError: user startup broke", err)
        self.assertIn("hooked True", out, err)
        self.assertIn("still here", out, err)


@unittest.skipUnless(
    importlib.util.find_spec("IPython"), "IPython is not installed"
)
class IPythonStartupTest(unittest.TestCase):
    def test_activates_loader(self):
        out, err = run_ipython(HOOKED)
        self.assertIn("hooked True", out, err)

    def test_display_shows_png_inline(self):
        out, err = run_ipython(PNG_OBJECT + "display(Picture())\n")
        self.assertEqual(out.count("\x1b]51;iron-image;"), 1, err)

    def test_bare_result_shows_png_inline(self):
        out, err = run_ipython(PNG_OBJECT + "Picture()\n")
        self.assertEqual(out.count("\x1b]51;iron-image;"), 1, err)

    def test_text_output_unchanged(self):
        out, err = run_ipython("6 * 7\n")
        self.assertIn("42", out, err)
        self.assertNotIn("iron-image", out)


if __name__ == "__main__":
    unittest.main()
