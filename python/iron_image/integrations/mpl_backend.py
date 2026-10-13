"""Matplotlib Agg backend that shows figures inline in an iron REPL."""

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
