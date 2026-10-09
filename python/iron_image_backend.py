"""Matplotlib Agg backend that shows figures inline in an iron REPL."""

import io

from iron_image import display
from matplotlib._pylab_helpers import Gcf
from matplotlib.backend_bases import FigureManagerBase
from matplotlib.backends.backend_agg import FigureCanvasAgg


class FigureManager(FigureManagerBase):
    def show(self) -> None:
        output = io.BytesIO()
        self.canvas.figure.savefig(output, format="png")
        display(output.getvalue())


class FigureCanvas(FigureCanvasAgg):
    manager_class = FigureManager  # pyright: ignore[reportAssignmentType]


def show(*, block: bool | None = None) -> None:
    """Shows every open figure, then closes them."""
    for manager in Gcf.get_all_fig_managers():
        manager.show()
    # Shown figures are done, like matplotlib-inline; otherwise every later
    # show() would render them again.
    Gcf.destroy_all()
