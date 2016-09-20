# encoding:utf-8
"""TCL repl definitions"""
from iron.repls.utils.cmd import detect_fn

repl = {
    'command': 'tclsh',
    'language': 'tcl',
    'detect': detect_fn("tclsh")
}
