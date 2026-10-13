"""Shared fixtures for the iron_image tests.

Every test runs Python in a fresh process: the loader changes sys.meta_path
for the whole process, and the startups need a real REPL. The ``iron``
fixture starts those processes with iron_image importable and guards that
keep tests away from the user's screen (no browser, no image viewer).
"""

import os
import re
import subprocess
import sys
import textwrap
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

import pytest

PYTHON_DIR = Path(__file__).resolve().parents[2] / "python"
STARTUP = PYTHON_DIR / "iron_image" / "startup" / "python.py"
FIRST_CHUNK = re.compile(r"\x1b\]51;iron-image;\d+;\d+;\d+;0;")


@dataclass
class Result:
    out: str
    err: str
    code: int

    @property
    def images(self) -> int:
        """How many images the process sent to iron."""
        return len(FIRST_CHUNK.findall(self.out))


class Iron:
    """Starts Python processes the way iron starts REPLs."""

    def __init__(self, image_dir: Path) -> None:
        self.image_dir = image_dir

    def python(
        self,
        code: str,
        *,
        pythonpath: Iterable[Path] = (),
        **env: str | None,
    ) -> Result:
        """Runs ``code`` with ``python -c``."""
        return self._run(["-c", textwrap.dedent(code)], None, pythonpath, env)

    def repl(self, stdin: str, **env: str | None) -> Result:
        """Feeds ``stdin`` to a plain python REPL started like iron does."""
        env = {
            "PYTHONSTARTUP": str(STARTUP),
            "PYTHON_BASIC_REPL": "1",
            **env,
        }
        return self._run(["-i", "-q"], textwrap.dedent(stdin), (), env)

    def ipython(self, stdin: str, **env: str | None) -> Result:
        """Feeds ``stdin`` to an ipython REPL started like iron does."""
        args = [
            "-m",
            "IPython",
            "--no-banner",
            "--colors=nocolor",
            "--ext=iron_image.startup.ipython",
        ]
        return self._run(args, textwrap.dedent(stdin), (), env)

    def _run(
        self,
        args: list[str],
        stdin: str | None,
        pythonpath: Iterable[Path],
        overrides: dict[str, str | None],
    ) -> Result:
        env = {
            k: v
            for k, v in os.environ.items()
            if not k.startswith("IRON_")
            and k not in ("PYTHONSTARTUP", "MPLBACKEND")
        }
        env.update(
            PYTHONPATH=os.pathsep.join(map(str, [PYTHON_DIR, *pythonpath])),
            IRON_IMAGE_NAMESPACE="130",
            IRON_IMAGE_DIR=str(self.image_dir),
            # Never reach the user's screen, even when the code under test
            # is broken: plotly's own default renderer opens a browser
            PLOTLY_RENDERER="json",
            BROWSER="true",
        )
        for key, value in overrides.items():
            if value is None:
                env.pop(key, None)
            else:
                env[key] = value
        result = subprocess.run(
            [sys.executable, *args],
            input=stdin,
            capture_output=True,
            text=True,
            env=env,
            timeout=120,
        )
        return Result(result.stdout, result.stderr, result.returncode)


@pytest.fixture
def iron(tmp_path: Path) -> Iron:
    image_dir = tmp_path / "images"
    image_dir.mkdir()
    return Iron(image_dir)
