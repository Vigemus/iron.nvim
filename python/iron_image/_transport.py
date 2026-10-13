"""Sends PNGs to iron as OSC 51 ``iron-image`` sequences."""

import base64
import sys

CHUNK_SIZE = 4096


def send(image_id: int, cols: int, rows: int, png: bytes) -> None:
    """Sends the PNG to iron in CHUNK_SIZE pieces."""
    payload = base64.b64encode(png).decode("ascii")
    for part, offset in enumerate(range(0, len(payload), CHUNK_SIZE)):
        chunk = payload[offset : offset + CHUNK_SIZE]
        more = int(offset + CHUNK_SIZE < len(payload))
        sys.stdout.write(
            f"\x1b]51;iron-image;{image_id};{cols};{rows};{part};{more};{chunk}\x07"
        )
