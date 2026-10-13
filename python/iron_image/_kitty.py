"""Kitty Unicode placeholders, the cells kitty draws an image over."""

import sys

# Kitty Unicode placeholder and the first MAX_ROWS row/column diacritics.
PLACEHOLDER = "\U0010eeee"
DIACRITICS = (
    "\u0305\u030d\u030e\u0310\u0312\u033d\u033e\u033f\u0346\u034a"
    "\u034b\u034c\u0350\u0351\u0352\u0357\u035b\u0363\u0364\u0365"
)


def placeholders(image_id: int, cols: int, rows: int, indent: str) -> None:
    """Prints the cells kitty draws the image over.

    The image id travels in the 24-bit foreground color and each row is
    marked with its own diacritic.
    """
    red, green, blue = image_id >> 16, (image_id >> 8) & 255, image_id & 255
    color = f"\x1b[38;2;{red};{green};{blue}m"
    for row in range(rows):
        cells = (
            PLACEHOLDER
            + DIACRITICS[row]
            + DIACRITICS[0]
            + PLACEHOLDER * (cols - 1)
        )
        sys.stdout.write(f"\r{indent}{color}{cells}\x1b[39m\r\n")
