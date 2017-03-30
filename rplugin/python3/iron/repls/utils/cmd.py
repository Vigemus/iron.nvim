from distutils.spawn import find_executable
import collections
from functools import partial
import logging
import os

logger = logging.getLogger(__name__)

if 'NVIM_IRON_DEBUG_FILE' in os.environ:
    logfile = os.environ['NVIM_IRON_DEBUG_FILE'].strip()
    logger.addHandler(logging.FileHandler(logfile, 'w'))

logger.level = logging.DEBUG


def detect_repl_installed(repl):
    """Checks whether a executable exists.
    :returns: True
    """
    if isinstance(repl, list):
        return all(map(find_executable, repl))

    return find_executable(repl) is not None


def detect_any_of_exists(files):
    """Checks whether any of the supplied files exist.
    :returns: True
    """
    return any(map(os.path.exists, files))

def detect_fn(executable, required_files=None):
    """Generates a function that checks whether the pre-reqs are met."""
    def check(iron, *args, **kwargs):

        if required_files is not None:
            pwd = iron.get_pwd()
            logger.info("Running on {}".format(pwd))
            join_pwd = partial(os.path.join, pwd)

            files = list(required_files)

            files.extend(list(map(join_pwd, required_files)))

            logger.info("Scanning for the following files:\n {}".format(
                files
            ))

            files = detect_any_of_exists(files)
            logger.info("Found" if files else "Not Found")
        else:
            files = True

        return files and detect_repl_installed(executable)

    return check

