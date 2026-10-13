"""Opens a pickled matplotlib figure in an interactive window.

    python -m iron_image.viewer <file.pickle>

iron runs this for :IronImageOpen with the Python of the REPL that made
the figure. It exits 0 when the window is closed and 1 with a message on
stderr when the figure can't be shown.
"""

import pickle
import sys


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(
            "usage: python -m iron_image.viewer <file.pickle>", file=sys.stderr
        )
        return 1
    import matplotlib.pyplot as plt

    try:
        with open(argv[1], "rb") as file:
            figure = pickle.load(file)
    except Exception as error:
        print(f"iron: cannot load figure: {error}", file=sys.stderr)
        return 1

    # Figures made with pyplot reattach to the current backend on load;
    # non-interactive backends (agg) have no GUI framework.
    if type(figure.canvas).required_interactive_framework is None:
        print(
            "iron: no interactive matplotlib backend"
            f" ({plt.get_backend()}); install PyQt6 or tkinter",
            file=sys.stderr,
        )
        return 1

    plt.show()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
