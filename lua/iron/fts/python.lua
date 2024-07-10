-- luacheck: globals vim
local bracketed_paste_python = require("iron.fts.common").bracketed_paste_python
local python = {}

local executable = function(exe)
  return vim.api.nvim_call_function('executable', {exe}) == 1
end

local pyversion  = executable('python3') and 'python3' or 'python'

local def = function(cmd)
	return {
		command = cmd,
		format = bracketed_paste_python
	}
end

python.ptipython = def({"ptipython"})
python.ipython = def({"ipython", "--no-autoindent"})
python.ptpython = def({"ptpython"})
python.python = def({pyversion})

return python
