"""Tests for iron_image.integrations.matplotlib, installed by the loader."""

import importlib.util
import os
import re
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

PYTHON_DIR = Path(__file__).resolve().parents[2] / "python"

PRELUDE = """
from iron_image import _loader
_loader.activate("python")
"""


def run(code: str, image_dir: str) -> tuple[str, str, int]:
    env = {k: v for k, v in os.environ.items() if not k.startswith("IRON_")}
    env.pop("MPLBACKEND", None)
    env.update(
        PYTHONPATH=str(PYTHON_DIR),
        IRON_IMAGE_NAMESPACE="130",
        IRON_IMAGE_DIR=image_dir,
    )
    result = subprocess.run(
        [sys.executable, "-c", PRELUDE + textwrap.dedent(code)],
        capture_output=True,
        text=True,
        env=env,
        timeout=120,
    )
    return result.stdout, result.stderr, result.returncode


@unittest.skipUnless(
    importlib.util.find_spec("matplotlib"), "matplotlib is not installed"
)
class MatplotlibTest(unittest.TestCase):
    def test_import_selects_inline_backend(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, err, code = run(
                """
                import matplotlib.pyplot as plt
                print(plt.get_backend())
                """,
                tmp,
            )
        self.assertEqual(code, 0, err)
        self.assertEqual(out, "module://iron_image.integrations.matplotlib\n")

    def test_show_draws_inline_and_saves_pickle(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, err, code = run(
                """
                import matplotlib.pyplot as plt
                plt.plot([1, 2, 3])
                plt.show()
                plt.figure(); plt.figure()
                plt.show()
                """,
                tmp,
            )
            files = sorted(p.name for p in Path(tmp).iterdir())
        self.assertEqual(code, 0, err)
        first_chunks = re.findall(r"\x1b\]51;iron-image;\d+;\d+;\d+;0;", out)
        self.assertEqual(len(first_chunks), 3, "one image per figure")
        self.assertEqual(sum(f.endswith(".pickle") for f in files), 3, files)
        self.assertIn("python", files)

    def test_user_can_still_switch_backend(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, err, code = run(
                """
                import matplotlib.pyplot as plt
                plt.switch_backend("agg")
                plt.plot([1]); plt.show()
                print(plt.get_backend())
                """,
                tmp,
            )
        self.assertEqual(code, 0, err)
        self.assertNotIn("iron-image", out)
        self.assertTrue(out.endswith("agg\n"), out)


if __name__ == "__main__":
    unittest.main()
