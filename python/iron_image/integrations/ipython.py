"""IPython extension: shows PNG display data inline."""

import sys
from collections.abc import Callable
from typing import Any

from .._convert import from_mime
from .._core import show

_extensions: dict[int, tuple[Callable[..., Any], list[str]]] = {}


def load_ipython_extension(shell: Any) -> None:
    """Shows IPython PNG display data inline; other data passes through."""
    if id(shell) in _extensions:
        return
    original = shell.display_pub.publish
    active_types = list(shell.display_formatter.active_types)
    shell.display_formatter.active_types = list(
        dict.fromkeys([*active_types, "image/png"])
    )

    def publish(
        data: dict[str, Any], metadata: Any = None, **kwargs: Any
    ) -> Any:
        if "image/png" in data:
            try:
                show(from_mime(data["image/png"]))
                return None
            except (ValueError, TypeError, RuntimeError) as error:
                print(error, file=sys.stderr)
        return original(data, metadata=metadata, **kwargs)

    shell.display_pub.publish = publish
    _extensions[id(shell)] = (original, active_types)


def unload_ipython_extension(shell: Any) -> None:
    previous = _extensions.pop(id(shell), None)
    if previous:
        shell.display_pub.publish, shell.display_formatter.active_types = (
            previous
        )
