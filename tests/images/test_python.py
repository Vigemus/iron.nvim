"""Run with python -m unittest discover -s tests/images -p 'test_*.py'."""
import base64
from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import re
import struct
import sys
import unittest
from unittest.mock import patch
from types import SimpleNamespace
import tempfile
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "python"))
import iron_image


def png_bytes(width=2, height=2):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    pixels = (b"\0" + b"\xff\0\0" * width) * height
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))


class Images(unittest.TestCase):
    def setUp(self):
        self.env = patch.dict(os.environ, {"IRON_IMAGE_NAMESPACE": "128"})
        self.env.start()
        self.addCleanup(self.env.stop)

    def capture(self, action):
        output = io.StringIO()
        with redirect_stdout(output):
            action()
        return output.getvalue()

    def test_png_transport_and_placeholder_id(self):
        png = png_bytes() + b"\0" * 10000
        text = self.capture(lambda: iron_image.display(png))
        chunks = re.findall(r"\x1b\]51;iron-image;(\d+);(\d+);(\d+);(\d+);([01]);([^\x07]+)\x07", text)
        self.assertGreater(len(chunks), 1)
        self.assertEqual(base64.b64decode("".join(chunk[5] for chunk in chunks)), png)
        self.assertTrue(all(len(chunk[5]) <= 4096 for chunk in chunks))
        self.assertEqual([int(chunk[3]) for chunk in chunks], list(range(len(chunks))))
        self.assertEqual([chunk[4] for chunk in chunks], ["1"] * (len(chunks) - 1) + ["0"])
        image_id, cols, rows = map(int, chunks[0][:3])
        self.assertEqual(text.count(iron_image.PLACEHOLDER), cols * rows)
        self.assertIn(f"\x1b[38;2;{image_id >> 16};{image_id >> 8 & 255};{image_id & 255}m", text)
        self.assertIn(iron_image.PLACEHOLDER + iron_image.DIACRITICS[0] * 2, text)

    def test_invalid_png_does_not_emit_output(self):
        output = io.StringIO()
        with redirect_stdout(output), self.assertRaises(ValueError):
            iron_image.display(b"not a png")
        self.assertEqual(output.getvalue(), "")

    def test_tiny_terminal_and_tall_image(self):
        with patch.object(iron_image.shutil, "get_terminal_size", return_value=os.terminal_size((1, 1))):
            output = self.capture(lambda: iron_image.display(png_bytes(1, 100)))
        self.assertEqual(output.count(iron_image.PLACEHOLDER), 1)

    def test_ids_are_not_reused(self):
        first = self.capture(lambda: iron_image.display(png_bytes()))
        second = self.capture(lambda: iron_image.display(png_bytes()))
        pattern = r"iron-image;(\d+);"
        self.assertNotEqual(re.search(pattern, first)[1], re.search(pattern, second)[1])

    def test_matplotlib_show_emits_png(self):
        import matplotlib
        matplotlib.use("module://iron_image_backend")
        import matplotlib.pyplot as plt
        plt.plot([1, 2, 3], [1, 4, 9])
        try:
            output = self.capture(plt.show)
            self.assertIn("iron-image;", output)
            self.assertIn(iron_image.PLACEHOLDER, output)
        finally:
            plt.close("all")

    def test_ipython_png_and_text_fallback(self):
        from IPython.terminal.interactiveshell import TerminalInteractiveShell
        shell = TerminalInteractiveShell.instance()
        old_types = list(shell.display_formatter.active_types)
        original = shell.display_pub.publish
        iron_image.load_ipython_extension(shell)
        try:
            output = self.capture(lambda: shell.run_cell(
                "from IPython.display import Image, display\n"
                "display(Image(data=" + repr(png_bytes()) + "))"
            ))
            self.assertIn("iron-image;", output)
            text = self.capture(lambda: shell.display_pub.publish({"text/plain": "text survives"}))
            self.assertIn("text survives", text)
        finally:
            iron_image.unload_ipython_extension(shell)
        self.assertEqual(shell.display_formatter.active_types, old_types)
        self.assertEqual(shell.display_pub.publish, original)

    def test_jupyter_png_mime_transport(self):
        from jupyter_console.ptshell import ZMQTerminalInteractiveShell
        from traitlets.config import Configurable
        # Exercise the real console hook without starting its prompt or kernel.
        shell = ZMQTerminalInteractiveShell.__new__(ZMQTerminalInteractiveShell)
        Configurable.__init__(shell)
        shell.image_handler = "callable"
        shell.callable_image_handler = iron_image.display_jupyter
        shell.mime_preference = ["image/png"]
        output = self.capture(lambda: self.assertTrue(shell.handle_rich_data(
            {"image/png": base64.b64encode(png_bytes()).decode("ascii")}
        )))
        self.assertIn("iron-image;", output)
        self.assertIn(iron_image.PLACEHOLDER, output)
        self.assertFalse(shell.handle_rich_data({"text/plain": "text survives"}))
        self.assertFalse(shell.handle_rich_data({"image/jpeg": "unsupported"}))

    def test_jupyter_base_config_preserves_default_and_explicit_config(self):
        from jupyter_console.app import ZMQTerminalIPythonApp
        from jupyter_core.application import JupyterApp
        bundled = Path(iron_image.__file__).parent / "jupyter"
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "jupyter_console_config.py"
            config.write_text("c = get_config()\nc.ZMQTerminalInteractiveShell.banner = 'USER_CONFIG'\n")
            with patch.dict(os.environ, {
                "JUPYTER_CONFIG_PATH": str(bundled) + os.pathsep + directory,
                "JUPYTER_CONFIG_DIR": directory,
                "JUPYTER_DATA_DIR": directory,
                "JUPYTER_RUNTIME_DIR": directory,
            }):
                for extra in ([], ["--config=" + str(config)]):
                    app = ZMQTerminalIPythonApp()
                    try:
                        # Load the actual app config without initializing ZMQ channels.
                        JupyterApp.initialize(app, extra + [
                            "--ZMQTerminalInteractiveShell.image_handler=callable",
                            '--ZMQTerminalInteractiveShell.mime_preference=["image/png"]',
                        ])
                        settings = app.config.ZMQTerminalInteractiveShell
                        self.assertIs(settings.callable_image_handler, iron_image.display_jupyter)
                        self.assertEqual(settings.image_handler, "callable")
                        self.assertEqual(settings.mime_preference, ["image/png"])
                        self.assertEqual(settings.banner, "USER_CONFIG")
                    finally:
                        app.close_handlers()

    def test_jupyter_text_and_invalid_images_fall_back(self):
        self.assertFalse(iron_image.display_jupyter({"text/plain": "text survives"}))
        output = io.StringIO()
        errors = io.StringIO()
        with redirect_stdout(output), patch("sys.stderr", errors):
            self.assertFalse(iron_image.display_jupyter({"image/png": "invalid!"}))
            self.assertFalse(iron_image.display_jupyter({"image/png": base64.b64encode(b"not PNG").decode()}))
            with patch.object(iron_image, "MAX_PNG_BYTES", 3):
                self.assertFalse(iron_image.display_jupyter({"image/png": "AAAAAAAA"}))
        self.assertEqual(output.getvalue(), "")
        self.assertIn("12 MiB", errors.getvalue())

    def test_kernel_direct_display_publishes_mime_instead_of_terminal_ids(self):
        shell = type("ZMQInteractiveShell", (), {})()
        published = []
        shell.display_pub = SimpleNamespace(publish=published.append)
        with patch.dict(sys.modules, {"IPython": SimpleNamespace(get_ipython=lambda: shell)}):
            output = self.capture(lambda: iron_image.display(png_bytes()))
        self.assertEqual(output, "")
        self.assertEqual(base64.b64decode(published[0]["image/png"]), png_bytes())


if __name__ == "__main__":
    unittest.main()
