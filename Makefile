.PHONY: test test-python

test:
	NVIM_APPNAME=nvim-iron-test \
	nvim --headless \
		-u NONE \
		-l tests/init.lua

PYTHON ?= python3

test-python:
	$(PYTHON) -m unittest discover -s tests/python -v
