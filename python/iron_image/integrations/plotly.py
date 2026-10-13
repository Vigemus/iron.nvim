"""plotly: fig.show() draws figures inline; :IronImageOpen opens the
interactive chart in the browser.

Registers an "iron" renderer and makes it plotly's default. The PNG comes
from kaleido, which renders plotly.js in a hidden Chrome; one Chrome is
started on the first figure and kept for the REPL's lifetime so later
figures are fast. Without kaleido or Chrome, figures open the way plotly
would have opened them (usually the browser), with a one-time hint.
"""

import atexit
import sys
import warnings
from functools import partial
from pathlib import Path
from typing import Any

import plotly.io as pio
from plotly.io.base_renderers import ExternalRenderer

from .._core import InteractiveFile
from .._core import show as show_png

_hinted = False
_server_started = False


def install_python() -> None:
    _use_iron_renderer()


def install_ipython() -> None:
    _use_iron_renderer()


def _use_iron_renderer() -> None:
    previous = pio.renderers.default
    pio.renderers["iron"] = _IronRenderer(previous)
    pio.renderers.default = "iron"


class _IronRenderer(ExternalRenderer):
    def __init__(self, fallback: str | None) -> None:
        # The renderer plotly would have used without iron; never ourselves,
        # or a failing figure would come straight back here
        self._fallback = (
            fallback if fallback and fallback != "iron" else "browser"
        )

    def render(self, fig: dict[str, Any]) -> None:
        try:
            png = _to_png(fig)
        except Exception as error:
            _hint(error)
            pio.show(fig, renderer=self._fallback)
            return
        show_png(png, InteractiveFile(".html", partial(_write_html, fig)))


def _to_png(fig_dict: dict[str, Any]) -> bytes:
    _start_server()
    with warnings.catch_warnings():
        # plotly passes options a running kaleido server ignores
        warnings.filterwarnings(
            "ignore", message=".*kopts argument is ignored"
        )
        return pio.to_image(fig_dict, format="png")


def _start_server() -> None:
    """Keeps one Chrome running for kaleido, when kaleido supports it."""
    global _server_started
    if _server_started:
        return
    _server_started = True
    import kaleido

    start = getattr(kaleido, "start_sync_server", None)
    stop = getattr(kaleido, "stop_sync_server", None)
    if start is None or stop is None:
        return  # older kaleido: one Chrome per figure
    start()
    atexit.register(stop)


def _write_html(fig_dict: dict[str, Any], path: Path) -> None:
    # "directory" writes plotly.min.js once next to the files, so the
    # charts open offline (documented value; plotly's annotation says bool)
    pio.write_html(
        fig_dict,
        str(path),
        include_plotlyjs="directory",  # pyright: ignore[reportArgumentType]
    )


def _hint(error: Exception) -> None:
    global _hinted
    if _hinted:
        return
    _hinted = True
    # plotly remembers a missing kaleido, so installing it needs a restart
    print(
        "iron: inline plotly needs kaleido and Chrome in this REPL's Python"
        " (%pip install kaleido / plotly_get_chrome, then restart the REPL):"
        f" {error}",
        file=sys.stderr,
    )
