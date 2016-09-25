# encoding:utf-8
""" Extra functions

Some extra functions  with functionalities that can be moved on from this
plugin.
"""


def selection_window(nvim, **options):
    size = len(options["select_options"]) + 4

    if "header" in options:
        size += 1

    size = min(size, 15)

    nvim.command("botright {} spl | enew".format(size))
    buf_id = nvim.call("bufnr", "$")
    sw_buf = nvim.buffers[buf_id]

    if "header" in options:
        sw_buf[0] = options["header"]

    select_options = options["select_options"]

    [nvim.command(i) for i in [
        "map <buffer> {} {}".format(k, c) for k, _, c in select_options
    ]]


    text = ["Select an option below:", ""] + [
        "    ({}) {}".format(k, t) for k, t, _ in select_options
    ]

    sw_buf.append(text)
