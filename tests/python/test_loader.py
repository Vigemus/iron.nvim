"""Tests for iron_image._loader, the import hook that installs integrations.

Each test runs in a fresh Python process: the hook changes sys.meta_path for
the whole process. A fake library ``fakelib`` and a fake integration for it
are written to a temporary directory.
"""

import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

PYTHON_DIR = Path(__file__).resolve().parents[2] / "python"

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


def run(code: str, integration: str = INTEGRATION, library=LIBRARY):
    """Runs code after the prelude; returns (stdout, stderr, returncode)."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        for name, text in library.items():
            path = root / "lib" / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        (root / "integrations").mkdir()
        (root / "integrations" / "fakelib.py").write_text(
            textwrap.dedent(integration)
        )
        script = PRELUDE.format(integrations=str(root / "integrations"))
        env = {
            **os.environ,
            "PYTHONPATH": os.pathsep.join(
                [str(PYTHON_DIR), str(root / "lib")]
            ),
        }
        result = subprocess.run(
            [sys.executable, "-c", script + textwrap.dedent(code)],
            capture_output=True,
            text=True,
            env=env,
            timeout=60,
        )
        return result.stdout, result.stderr, result.returncode


class LoaderTest(unittest.TestCase):
    def test_installs_after_import(self):
        out, err, code = run("""
            _loader.activate("python")
            import fakelib
            print("imported", fakelib.VALUE)
        """)
        self.assertEqual(code, 0, err)
        self.assertEqual(
            out.split("\n")[:2], ["install_python 1", "imported 1"]
        )

    def test_installs_once(self):
        out, err, code = run("""
            _loader.activate("python")
            import fakelib
            import importlib
            importlib.reload(fakelib)
            import fakelib
        """)
        self.assertEqual(code, 0, err)
        self.assertEqual(out.count("install_python"), 1)

    def test_submodule_import_installs_parent(self):
        out, err, code = run("""
            _loader.activate("python")
            import fakelib.sub
            print("sub", fakelib.sub.SUB)
        """)
        self.assertEqual(code, 0, err)
        self.assertEqual(out.split("\n")[:2], ["install_python 1", "sub 2"])

    def test_unlisted_package_untouched(self):
        out, err, code = run("""
            _loader.activate("python")
            import otherlib
            print("ok")
        """)
        self.assertEqual((code, out, err), (0, "ok\n", ""))

    def test_nothing_before_activate(self):
        out, err, code = run("""
            import fakelib
            print("imported")
        """)
        self.assertEqual((code, out), (0, "imported\n"), err)

    def test_already_imported_installs_on_activate(self):
        out, err, code = run("""
            import fakelib
            print("before")
            _loader.activate("python")
        """)
        self.assertEqual(code, 0, err)
        self.assertEqual(out, "before\ninstall_python 1\n")

    def test_repl_without_install_function_gets_nothing(self):
        out, err, code = run("""
            _loader.activate("ipython")
            import fakelib
            print("imported")
        """)
        self.assertEqual((code, out, err), (0, "imported\n", ""))

    def test_failing_install_warns_and_import_succeeds(self):
        out, err, code = run(
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
        self.assertEqual((code, out), (0, "imported 1\n"), err)
        self.assertIn("iron: fakelib integration failed: boom", err)

    def test_broken_integration_module_warns(self):
        out, err, code = run(
            """
            _loader.activate("python")
            import fakelib
            print("imported")
            """,
            integration="raise ImportError('missing dependency')\n",
        )
        self.assertEqual((code, out), (0, "imported\n"), err)
        self.assertIn("missing dependency", err)

    def test_misnamed_install_function_warns(self):
        _, err, code = run(
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
        self.assertEqual(code, 0, err)
        self.assertIn("install_Ipython() matches no REPL", err)

    def test_library_import_error_propagates_and_retries(self):
        library = {
            **LIBRARY,
            "fakelib/__init__.py": "import os\nif not os.environ.get('OK'):\n    raise ImportError('broken')\nVALUE = 1\n",
        }
        out, err, code = run(
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
            library=library,
        )
        self.assertEqual(code, 0, err)
        self.assertEqual(out, "failed broken\ninstall_python 1\nimported 1\n")

    def test_package_keeps_its_own_loader(self):
        out, err, code = run("""
            _loader.activate("python")
            import fakelib
            print(type(fakelib.__loader__).__name__)
            print(type(fakelib.__spec__.loader).__name__)
        """)
        self.assertEqual(code, 0, err)
        self.assertEqual(
            out.split("\n")[1:3], ["SourceFileLoader", "SourceFileLoader"]
        )

    def test_activate_twice_is_harmless(self):
        out, err, code = run("""
            import sys
            _loader.activate("python")
            _loader.activate("ipython")
            import fakelib
            print(sum(type(f).__name__ == "_Finder" for f in sys.meta_path))
        """)
        self.assertEqual(code, 0, err)
        self.assertEqual(out, "install_python 1\n1\n")


if __name__ == "__main__":
    unittest.main()
