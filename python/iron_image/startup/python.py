"""Plain python REPL startup, run as PYTHONSTARTUP.

iron points PYTHONSTARTUP at this file and passes the user's own startup
file, if any, in IRON_PYTHONSTARTUP; it runs right after, the way Python
would have run it. Python runs this file in the REPL's namespace, so it
leaves no names behind.
"""


def _iron_startup() -> None:
    import os
    import traceback

    import __main__
    from iron_image._loader import activate

    activate("python")

    user_startup = os.environ.get("IRON_PYTHONSTARTUP")
    if not user_startup:
        return
    try:
        with open(user_startup, encoding="utf-8") as file:
            code = compile(file.read(), user_startup, "exec")
        exec(code, __main__.__dict__)
    except Exception:
        # Python reports a failing PYTHONSTARTUP and starts the REPL anyway
        traceback.print_exc()


_iron_startup()
del _iron_startup
