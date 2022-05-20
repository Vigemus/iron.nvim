-- luacheck: globals vim
local bracketed_paste = require("iron.fts.common").bracketed_paste
local python = {}

local has = function(feature)
  return vim.api.nvim_call_function('has', {feature}) == 1
end

local executable = function(exe)
  return vim.api.nvim_call_function('executable', {exe}) == 1
end

local windows_linefeed = function(lines)
  for idx,line in ipairs(lines) do
    lines[idx] = line .. '\13'
  end
  return lines
end

local is_windows = has('win32') and true or false
local pyversion  = executable('python3') and 'python3' or 'python'


local def = function(cmd)
  return {
    command = cmd,
    format = bracketed_paste
  }
end

python.ptipython = def({"ptipython"})
python.ipython = def({"ipython", "--no-autoindent"})
python.ptpython = def({"ptpython"})
python.python = {
  command = {pyversion},
  close = {""}
}

if is_windows then
  python.python.format = windows_linefeed
end

return python
