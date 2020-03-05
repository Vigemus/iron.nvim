local extend = require("iron.util.tables").extend
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

local format = function(open, close, cr)
  return function(lines)
    if #lines == 1 then
      return { lines[1] .. cr }
    else
      local new = { open .. lines[1] }
      for line=2, #lines do
        table.insert(new, lines[line])
      end
      return extend(new, close)
    end
  end
end

local def = function(cmd)
  return {
    command = cmd,
    format = format("\27[200~", "\27[201~\13", "\13")
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
