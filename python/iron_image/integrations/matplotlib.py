"""matplotlib: plt.show() draws figures inline; :IronImageOpen reopens them
in an interactive window.

The install functions select this module as matplotlib's backend: an Agg
backend whose show() sends each figure to iron_image.show() as a PNG, with a
pickle of the figure as its interactive file (opened by iron_image.viewer).
"""

import io
import pickle
from functools import partial
from pathlib import Path

from matplotlib._pylab_helpers import Gcf
from matplotlib.backend_bases import FigureManagerBase
from matplotlib.backends.backend_agg import FigureCanvasAgg
from matplotlib.figure import Figure

from .._core import InteractiveFile
from .._core import show as show_png


class FigureManager(FigureManagerBase):
    def show(self) -> None:
        figure = self.canvas.figure
        output = io.BytesIO()
        figure.savefig(output, format="png")
        # The pickle lets :IronImageOpen reopen the figure in a window
        # (iron_image.viewer)
        show_png(
            output.getvalue(),
            InteractiveFile(".pickle", partial(_pickle, figure)),
        )


def _pickle(figure: Figure, path: Path) -> None:
    with path.open("wb") as file:
        pickle.dump(figure, file)


class FigureCanvas(FigureCanvasAgg):
    manager_class = FigureManager  # pyright: ignore[reportAssignmentType]


def show(*, block: bool | None = None) -> None:
    """Shows every open figure, then closes them."""
    for manager in Gcf.get_all_fig_managers():
        manager.show()
    # Shown figures are done, like matplotlib-inline; otherwise every later
    # show() would render them again.
    Gcf.destroy_all()


def install_python() -> None:
    _use_inline_backend()


def install_ipython() -> None:
    _use_inline_backend()


def _use_inline_backend() -> None:
    import matplotlib

    matplotlib.use(f"module://{__name__}")
