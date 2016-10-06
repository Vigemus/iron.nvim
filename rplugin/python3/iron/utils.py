# encoding:utf-8
""" Some helper functions. """

def select_keys(data, keys):
    return {k: data[k] for k in keys}
