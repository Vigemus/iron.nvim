"""Tests for iron_image.integrations.matplotlib, installed by the loader."""

import pytest
from conftest import Iron

pytest.importorskip("matplotlib")

PRELUDE = """
from iron_image import _loader
_loader.activate("python")
"""


def test_import_selects_inline_backend(iron: Iron):
    result = iron.python(
        PRELUDE
        + """
import matplotlib.pyplot as plt
print(plt.get_backend())
"""
    )
    assert result.code == 0, result.err
    assert result.out == "module://iron_image.integrations.matplotlib\n"


def test_show_draws_inline_and_saves_pickle(iron: Iron):
    result = iron.python(
        PRELUDE
        + """
import matplotlib.pyplot as plt
plt.plot([1, 2, 3])
plt.show()
plt.figure(); plt.figure()
plt.show()
"""
    )
    files = sorted(p.name for p in iron.image_dir.iterdir())
    assert result.code == 0, result.err
    assert result.images == 3, "one image per figure"
    assert sum(f.endswith(".pickle") for f in files) == 3, files
    assert "python" in files


def test_user_can_still_switch_backend(iron: Iron):
    result = iron.python(
        PRELUDE
        + """
import matplotlib.pyplot as plt
plt.switch_backend("agg")
plt.plot([1]); plt.show()
print(plt.get_backend())
"""
    )
    assert result.code == 0, result.err
    assert result.images == 0
    assert result.out.endswith("agg\n"), result.out
