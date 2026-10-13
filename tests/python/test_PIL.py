"""Tests for iron_image.integrations.PIL, installed by the loader."""

import importlib.util
import os
import re
import subprocess
import sys
import textwrap
import unittest
from pathlib import Path

PYTHON_DIR = Path(__file__).resolve().parents[2] / "python"

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

FIRST_CHUNK = r"\x1b\]51;iron-image;\d+;\d+;\d+;0;"


def run(code: str, namespace: str = "130") -> tuple[str, str, int]:
    env = {k: v for k, v in os.environ.items() if not k.startswith("IRON_")}
    env.update(PYTHONPATH=str(PYTHON_DIR))
    if namespace:
        env["IRON_IMAGE_NAMESPACE"] = namespace
    result = subprocess.run(
        [sys.executable, "-c", PRELUDE + textwrap.dedent(code)],
        capture_output=True,
        text=True,
        env=env,
        timeout=60,
    )
    return result.stdout, result.stderr, result.returncode


@unittest.skipUnless(
    importlib.util.find_spec("PIL"), "Pillow is not installed"
)
class PillowTest(unittest.TestCase):
    def test_show_draws_inline(self):
        out, err, code = run("""
            Image.new("RGB", (8, 4), "red").show()
        """)
        self.assertEqual(code, 0, err)
        self.assertEqual(len(re.findall(FIRST_CHUNK, out)), 1)
        self.assertNotIn("fallback viewer", out)

    def test_modes_png_cannot_store_are_converted(self):
        out, err, code = run("""
            Image.new("CMYK", (8, 4)).show()
            Image.new("F", (8, 4)).show()
        """)
        self.assertEqual(code, 0, err)
        self.assertEqual(len(re.findall(FIRST_CHUNK, out)), 2)

    def test_failure_warns_and_falls_back_to_other_viewers(self):
        out, err, code = run(
            """
            Image.new("RGB", (8, 4)).show()
            """,
            namespace="",
        )
        self.assertEqual(code, 0, err)
        self.assertIn("fallback viewer", out)
        self.assertIn("enable image = true", err)


if __name__ == "__main__":
    unittest.main()
