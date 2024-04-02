-- luacheck: globals vim
local bracketed_paste = require("iron.fts.common").bracketed_paste
local python = {}

--- @param lines table  "each item of the table is a new line to send to the repl"
--- @return table  "returns the table of lines to be sent the the repl with 
-- the return carriage '\r' added"
local function bracketed_paste_python(lines)
  local cr = "\r"
  local result = {}

  for i, line in ipairs(lines) do
    table.insert(result, line)

    if i < #lines then
      local current_line_has_indent = string.match(line, "^%s") ~= nil
      local next_line_has_indent = string.match(lines[i + 1], "^%s") ~= nil

      if current_line_has_indent and not next_line_has_indent then
        table.insert(result, cr)
      end

    end
  end

  table.insert(result, cr)
  return result
end

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
  format = bracketed_paste_python,
  close = {""}
}

if is_windows then
  python.python.format = windows_linefeed
end

return python
