"""Turns the things users display into checked PNG bytes."""

import base64
import os
from typing import Any, Protocol, TypeAlias

MAX_PNG_BYTES = 12 * 1024 * 1024
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class SupportsReprPng(Protocol):
    def _repr_png_(self) -> Any: ...


Image: TypeAlias = str | os.PathLike[str] | bytes | bytearray | SupportsReprPng


def to_png(image: Image) -> bytes:
    if isinstance(image, (str, os.PathLike)):
        with open(image, "rb") as source:
            return source.read(MAX_PNG_BYTES + 1)
    if isinstance(image, (bytes, bytearray)):
        return bytes(image)
    if hasattr(image, "_repr_png_"):
        data = image._repr_png_()
        if isinstance(data, tuple):
            data = data[0]
        if isinstance(data, (str, bytes)):
            return from_mime(data)
        raise ValueError("iron: object did not provide PNG data")
    raise TypeError(
        "iron: display expects PNG bytes, a PNG path, or _repr_png_"
    )


def from_mime(data: str | bytes) -> bytes:
    """PNG bytes from IPython display data, which may be base64 text."""
    if isinstance(data, str):
        return base64.b64decode(data, validate=True)
    return data


def check_png(png: bytes) -> None:
    if len(png) > MAX_PNG_BYTES:
        raise ValueError("iron: PNG exceeds the 12 MiB image limit")
    if not png.startswith(PNG_SIGNATURE) or png[12:16] != b"IHDR":
        raise ValueError("iron: expected PNG data")
