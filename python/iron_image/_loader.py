"""Installs library integrations when the user imports the library.

A startup module (``startup/<repl>.py``) calls ``activate(repl)`` once when
the REPL starts. From then on, whenever a package listed in
``integrations.INTEGRATIONS`` finishes importing, the loader imports
``integrations.<package>`` and calls its ``install_<repl>()``, if it has one.

The finder sits in front of every import, so it only ever acts on the
listed top-level packages and never lets its own errors reach the user's
import.
"""

import importlib
import importlib.abc
import importlib.machinery
import sys
from collections.abc import Sequence
from types import ModuleType
from typing import Any

from . import integrations
from .startup import REPLS

_repl: str | None = None
_installed: set[str] = set()


def activate(repl: str) -> None:
    """Installs integrations for ``repl`` from now on; runs once per REPL."""
    global _repl
    if _repl is not None:
        return
    _repl = repl
    sys.meta_path.insert(0, _Finder())
    for name in integrations.INTEGRATIONS:
        # Imported before the REPL started us, e.g. by a profile
        if name in sys.modules:
            _install(name)


def _install(name: str) -> None:
    """Imports the integration for package ``name`` and runs its install."""
    if name in _installed:
        return
    _installed.add(name)
    try:
        integration = importlib.import_module(
            f"{integrations.__name__}.{name}"
        )
        _check_names(name, integration)
        install = getattr(integration, f"install_{_repl}", None)
        if install is not None:
            install()
    except Exception as error:
        print(f"iron: {name} integration failed: {error}", file=sys.stderr)


def _check_names(name: str, integration: ModuleType) -> None:
    """Warns about install functions for REPLs that don't exist."""
    for attr in vars(integration):
        if (
            attr.startswith("install_")
            and attr[len("install_") :] not in REPLS
        ):
            print(
                f"iron: {name} integration: {attr}() matches no REPL"
                f" ({', '.join(REPLS)})",
                file=sys.stderr,
            )


class _Finder(importlib.abc.MetaPathFinder):
    """Wraps the loader of listed packages so we hear when they finish."""

    def find_spec(
        self,
        fullname: str,
        path: Sequence[str] | None,
        target: ModuleType | None = None,
    ) -> importlib.machinery.ModuleSpec | None:
        if fullname not in integrations.INTEGRATIONS or fullname in _installed:
            return None
        try:
            spec = _real_spec(self, fullname, path, target)
        except Exception:
            return None
        if spec is None or spec.loader is None:
            return None
        spec.loader = _Loader(spec.loader, fullname)
        return spec


def _real_spec(
    finder: _Finder,
    fullname: str,
    path: Sequence[str] | None,
    target: ModuleType | None,
) -> importlib.machinery.ModuleSpec | None:
    """The spec the rest of sys.meta_path would have produced."""
    for other in sys.meta_path:
        if other is finder:
            continue
        find_spec = getattr(other, "find_spec", None)
        if find_spec is None:
            continue
        spec = find_spec(fullname, path, target)
        if spec is not None:
            return spec
    return None


class _Loader(importlib.abc.Loader):
    """Runs the real loader, then installs the integration."""

    def __init__(self, loader: Any, name: str) -> None:
        self._loader = loader
        self._name = name

    def __getattr__(self, attr: str) -> Any:
        return getattr(self._loader, attr)

    def create_module(self, spec: importlib.machinery.ModuleSpec) -> Any:
        return self._loader.create_module(spec)

    def exec_module(self, module: ModuleType) -> None:
        # The package sees its own loader, as if we were never there
        module.__loader__ = self._loader
        if module.__spec__ is not None:
            module.__spec__.loader = self._loader
        self._loader.exec_module(module)
        _install(self._name)
