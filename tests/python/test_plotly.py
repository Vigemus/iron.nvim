"""Tests for iron_image.integrations.plotly, installed by the loader.

The inline tests need plotly, kaleido and a Chrome; the others only plotly.
"""

import importlib.util

import pytest
from conftest import Iron

pytest.importorskip("plotly")

needs_kaleido = pytest.mark.skipif(
    importlib.util.find_spec("kaleido") is None,
    reason="kaleido is not installed",
)

PRELUDE = """
from iron_image import _loader
_loader.activate("python")
"""


def test_renderer_becomes_default(iron: Iron):
    result = iron.python(
        PRELUDE
        + """
import plotly.io as pio
print(pio.renderers.default)
"""
    )
    assert (result.code, result.out) == (0, "iron\n"), result.err


@needs_kaleido
def test_show_draws_inline_and_writes_offline_html(iron: Iron):
    result = iron.python(
        PRELUDE
        + """
import plotly.graph_objects as go
go.Figure(go.Scatter(y=[1, 3, 2])).show()
go.Figure(go.Bar(y=[2, 1])).show()
"""
    )
    files = sorted(p.name for p in iron.image_dir.iterdir())
    html = [f for f in files if f.endswith(".html")]
    assert result.code == 0, result.err
    assert result.images == 2
    assert len(html) == 2, files
    assert "plotly.min.js" in files
    assert 'src="plotly.min.js"' in (iron.image_dir / html[0]).read_text()
    assert "kopts" not in result.err


def test_without_kaleido_falls_back_with_one_hint(iron: Iron):
    result = iron.python("""
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
    """)
    assert result.code == 0, result.err
    assert result.out.count("fallback renderer") == 2
    assert result.images == 0
    assert result.err.count("iron: inline plotly needs kaleido") == 1
