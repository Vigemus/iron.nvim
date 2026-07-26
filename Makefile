.PHONY: test

test:
	NVIM_APPNAME=nvim-iron-test \
	nvim --headless \
		-u NONE \
		-l tests/init.lua
