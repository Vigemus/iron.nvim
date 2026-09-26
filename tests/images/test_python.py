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


if __name__ == "__main__":
    unittest.main()
