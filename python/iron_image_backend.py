"""Matplotlib's Agg renderer with inline output to an Iron terminal REPL."""

import io

from iron_image import display
from matplotlib._pylab_helpers import Gcf
from matplotlib.backend_bases import FigureManagerBase
from matplotlib.backends.backend_agg import FigureCanvasAgg


class FigureManager(FigureManagerBase):
    def show(self):
        output = io.BytesIO()
        self.canvas.print_png(output)
        display(output.getvalue())


class FigureCanvas(FigureCanvasAgg):
    manager_class = FigureManager


def show(*, block=None):
    for manager in Gcf.get_all_fig_managers():
        manager.show()
