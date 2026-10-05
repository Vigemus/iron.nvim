"""Base config loaded by Jupyter-console through Iron's JUPYTER_CONFIG_PATH.

Keep the normal console config (including --config) and its other settings.
The renderer runs in the frontend, so existing kernels need no Iron extension.
"""

from iron_image import display_jupyter

c = get_config()  # noqa: F821 - supplied by Jupyter's config loader
c.ZMQTerminalInteractiveShell.callable_image_handler = display_jupyter
