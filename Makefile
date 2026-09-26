.PHONY: test test-images

test:
	NVIM_APPNAME=nvim-iron-test \
	nvim --headless \
		-u NONE \
		-l tests/init.lua

# Requires Python with matplotlib and IPython in the active environment.
test-images:
	python -m unittest discover -s tests/images -p 'test_*.py'
	nvim --headless -u NONE -l tests/images/integration.lua
