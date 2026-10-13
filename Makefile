.PHONY: test test-python

test:
	NVIM_APPNAME=nvim-iron-test \
	nvim --headless \
		-u NONE \
		-l tests/init.lua

test-python:
	pytest tests/python
