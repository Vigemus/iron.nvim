"""Tests for iron_image.integrations.plotly, installed by the loader.

Needs plotly, kaleido and a Chrome for the inline tests; the fallback test
only needs plotly.
"""

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

FIRST_CHUNK = r"\x1b\]51;iron-image;\d+;\d+;\d+;0;"

HAS_PLOTLY = importlib.util.find_spec("plotly") is not None
HAS_KALEIDO = importlib.util.find_spec("kaleido") is not None


def run(code: str, image_dir: str) -> tuple[str, str, int]:
    env = {k: v for k, v in os.environ.items() if not k.startswith("IRON_")}
    env.update(
        PYTHONPATH=str(PYTHON_DIR),
        IRON_IMAGE_NAMESPACE="130",
        IRON_IMAGE_DIR=image_dir,
        # Never reach the user's browser, even if the integration is broken:
        # plotly's own default would otherwise be "browser"
        PLOTLY_RENDERER="json",
        BROWSER="true",
    )
    result = subprocess.run(
        [sys.executable, "-c", textwrap.dedent(code)],
        capture_output=True,
        text=True,
        env=env,
        timeout=120,
    )
    return result.stdout, result.stderr, result.returncode


@unittest.skipUnless(HAS_PLOTLY, "plotly is not installed")
class PlotlyTest(unittest.TestCase):
    def test_renderer_becomes_default(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, err, code = run(
                """
                from iron_image import _loader
                _loader.activate("python")
                import plotly.io as pio
                print(pio.renderers.default)
                """,
                tmp,
            )
        self.assertEqual((code, out), (0, "iron\n"), err)

    @unittest.skipUnless(HAS_KALEIDO, "kaleido is not installed")
    def test_show_draws_inline_and_writes_offline_html(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, err, code = run(
                """
                from iron_image import _loader
                _loader.activate("python")
                import plotly.graph_objects as go
                go.Figure(go.Scatter(y=[1, 3, 2])).show()
                go.Figure(go.Bar(y=[2, 1])).show()
                """,
                tmp,
            )
            files = sorted(p.name for p in Path(tmp).iterdir())
            html = [f for f in files if f.endswith(".html")]
            text = (Path(tmp) / html[0]).read_text() if html else ""
        self.assertEqual(code, 0, err)
        self.assertEqual(len(re.findall(FIRST_CHUNK, out)), 2)
        self.assertEqual(len(html), 2, files)
        self.assertIn("plotly.min.js", files)
        self.assertIn('src="plotly.min.js"', text)
        self.assertNotIn("kopts", err)

    def test_without_kaleido_falls_back_with_one_hint(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, err, code = run(
                """
                import sys
                sys.modules["kaleido"] = None  # as if not installed
                import plotly.io as pio
                from plotly.io.base_renderers import ExternalRenderer

                class Fallback(ExternalRenderer):
                    def render(self, fig_dict):
                        print("fallback renderer")

                # plotly's renderer before iron installs, e.g. "browser"
                pio.renderers["fallback"] = Fallback()
                pio.renderers.default = "fallback"
                from iron_image import _loader
                _loader.activate("python")
                import plotly.graph_objects as go
                go.Figure(go.Scatter(y=[1])).show()
                go.Figure(go.Scatter(y=[2])).show()
                """,
                tmp,
            )
        self.assertEqual(code, 0, err)
        self.assertEqual(out.count("fallback renderer"), 2)
        self.assertNotIn("iron-image", out)
        self.assertEqual(err.count("iron: inline plotly needs kaleido"), 1)


if __name__ == "__main__":
    unittest.main()
