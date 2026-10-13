"""Tests for iron_image._loader, the import hook that installs integrations.

A fake library ``fakelib`` and a fake integration for it are written to a
temporary directory; ``otherlib`` has no integration.
"""

import textwrap
from collections.abc import Callable
from pathlib import Path

import pytest
from conftest import Iron, Result

LIBRARY = {
    "fakelib/__init__.py": "VALUE = 1\n",
    "fakelib/sub.py": "SUB = 2\n",
    "otherlib/__init__.py": "",
}

INTEGRATION = """
import fakelib

def install_python():
    print("install_python", fakelib.VALUE)
"""

PRELUDE = """
import iron_image.integrations as integrations
integrations.__path__.append({integrations!r})
integrations.INTEGRATIONS = ("fakelib",)
from iron_image import _loader
"""

Run = Callable[..., Result]


@pytest.fixture
def run(iron: Iron, tmp_path: Path) -> Run:
    """Runs code after the prelude, with fakelib and its integration."""

    def run(
        code: str,
        integration: str = INTEGRATION,
        library: dict[str, str] = LIBRARY,
    ) -> Result:
        for name, text in library.items():
            path = tmp_path / "lib" / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        integrations = tmp_path / "integrations"
        integrations.mkdir(exist_ok=True)
        (integrations / "fakelib.py").write_text(textwrap.dedent(integration))
        prelude = PRELUDE.format(integrations=str(integrations))
        return iron.python(
            prelude + textwrap.dedent(code), pythonpath=[tmp_path / "lib"]
        )

    return run


def test_installs_after_import(run: Run):
    result = run("""
        _loader.activate("python")
        import fakelib
        print("imported", fakelib.VALUE)
    """)
    assert result.code == 0, result.err
    assert result.out.split("\n")[:2] == ["install_python 1", "imported 1"]


def test_installs_once(run: Run):
    result = run("""
        _loader.activate("python")
        import fakelib
        import importlib
        importlib.reload(fakelib)
        import fakelib
    """)
    assert result.code == 0, result.err
    assert result.out.count("install_python") == 1


def test_submodule_import_installs_parent(run: Run):
    result = run("""
        _loader.activate("python")
        import fakelib.sub
        print("sub", fakelib.sub.SUB)
    """)
    assert result.code == 0, result.err
    assert result.out.split("\n")[:2] == ["install_python 1", "sub 2"]


def test_unlisted_package_untouched(run: Run):
    result = run("""
        _loader.activate("python")
        import otherlib
        print("ok")
    """)
    assert (result.code, result.out, result.err) == (0, "ok\n", "")


def test_nothing_before_activate(run: Run):
    result = run("""
        import fakelib
        print("imported")
    """)
    assert (result.code, result.out) == (0, "imported\n"), result.err


def test_already_imported_installs_on_activate(run: Run):
    result = run("""
        import fakelib
        print("before")
        _loader.activate("python")
    """)
    assert result.code == 0, result.err
    assert result.out == "before\ninstall_python 1\n"


def test_repl_without_install_function_gets_nothing(run: Run):
    result = run("""
        _loader.activate("ipython")
        import fakelib
        print("imported")
    """)
    assert (result.code, result.out, result.err) == (0, "imported\n", "")


def test_failing_install_warns_and_import_succeeds(run: Run):
    result = run(
        """
        _loader.activate("python")
        import fakelib
        print("imported", fakelib.VALUE)
        """,
        integration="""
        def install_python():
            raise RuntimeError("boom")
        """,
    )
    assert (result.code, result.out) == (0, "imported 1\n"), result.err
    assert "iron: fakelib integration failed: boom" in result.err


def test_broken_integration_module_warns(run: Run):
    result = run(
        """
        _loader.activate("python")
        import fakelib
        print("imported")
        """,
        integration="raise ImportError('missing dependency')\n",
    )
    assert (result.code, result.out) == (0, "imported\n"), result.err
    assert "missing dependency" in result.err


def test_misnamed_install_function_warns(run: Run):
    result = run(
        """
        _loader.activate("python")
        import fakelib
        """,
        integration="""
        def install_python():
            pass

        def install_Ipython():
            pass
        """,
    )
    assert result.code == 0, result.err
    assert "install_Ipython() matches no REPL" in result.err


def test_library_import_error_propagates_and_retries(run: Run):
    broken = (
        "import os\n"
        "if not os.environ.get('OK'):\n"
        "    raise ImportError('broken')\n"
        "VALUE = 1\n"
    )
    result = run(
        """
        import os
        _loader.activate("python")
        try:
            import fakelib
        except ImportError as error:
            print("failed", error)
        os.environ["OK"] = "1"
        import fakelib
        print("imported", fakelib.VALUE)
        """,
        library={**LIBRARY, "fakelib/__init__.py": broken},
    )
    assert result.code == 0, result.err
    assert result.out == "failed broken\ninstall_python 1\nimported 1\n"


def test_package_keeps_its_own_loader(run: Run):
    result = run("""
        _loader.activate("python")
        import fakelib
        print(type(fakelib.__loader__).__name__)
        print(type(fakelib.__spec__.loader).__name__)
    """)
    assert result.code == 0, result.err
    loaders = result.out.split("\n")[1:3]
    assert loaders == ["SourceFileLoader", "SourceFileLoader"]


def test_activate_twice_is_harmless(run: Run):
    result = run("""
        import sys
        _loader.activate("python")
        _loader.activate("ipython")
        import fakelib
        print(sum(type(f).__name__ == "_Finder" for f in sys.meta_path))
    """)
    assert result.code == 0, result.err
    assert result.out == "install_python 1\n1\n"
