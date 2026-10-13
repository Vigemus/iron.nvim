"""Library integrations: show a library's images inline.

One module per Python library, named after the library's top-level import
name (``matplotlib.py``, ``PIL.py``), listed in ``INTEGRATIONS`` below.

The loader (``_loader.py``) imports ``integrations/<name>.py`` right after the
user imports ``<name>``, so the module may import its library at the top. It
then calls the module's install function for the current REPL:

    def install_python() -> None
    def install_ipython() -> None

Define one for each REPL in ``startup.REPLS`` the integration supports; a
REPL without one gets nothing. Logic shared by several REPLs goes in a
private helper they both call. An install function hooks the library so its
images reach ``iron_image.show(png, interactive=None)``, using only the
library's own mechanisms (backends, renderers, viewers): never replace other
code's functions or add methods to its classes. If it raises, the loader
prints a warning and the REPL carries on without the integration.
"""

INTEGRATIONS: tuple[str, ...] = ("matplotlib",)
