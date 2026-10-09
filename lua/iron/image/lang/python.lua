-- luacheck: globals vim
--- Loads iron's Python helper (python/iron_image.py) into python and
-- ipython REPLs and routes matplotlib through it.
local is_windows = require("iron.util.os").is_windows

---@class iron.image.PythonLang : iron.image.Lang
local python = {}

--- Directory holding the bundled Python helper
---@return string
local helper_dir = function()
  local paths = vim.api.nvim_get_runtime_file("python/iron_image.py", false)
  if #paths == 0 then
    error("python/iron_image.py not found in runtimepath", 0)
  end
  return vim.fn.fnamemodify(paths[1], ":h")
end

--- Whether cmd runs ipython; errors for commands that can't load the helper
---@param cmd string[]
---@return boolean
local is_ipython = function(cmd)
  local name = vim.fn.fnamemodify(cmd[1], ":t"):lower():gsub("%.exe$", "")
  if name:match("^ipython[%d.]*$") then
    return true
  elseif not name:match("^python[%d.]*$") then
    error("images need a python or ipython command, got " .. cmd[1], 0)
  end

  for i = 2, #cmd do
    if cmd[i] == "-m" then
      return cmd[i + 1] == "IPython"
    elseif cmd[i] == "-I" or cmd[i] == "-E" then
      error("images need python to read PYTHONPATH (remove -I/-E)", 0)
    end
  end
  return false
end

--- Adapts a REPL command and environment so it can emit images
---@param cmd string[] resolved command, modified in place
---@param env table<string, string> environment, modified in place
---@return string[] cmd
---@return table<string, string> env
python.prepare = function(cmd, env)
  if is_ipython(cmd) then
    table.insert(cmd, "--ext=iron_image")
  end

  local pythonpath = env.PYTHONPATH or vim.env.PYTHONPATH or ""
  local sep = is_windows() and ";" or ":"
  env.PYTHONPATH = helper_dir()
    .. (pythonpath ~= "" and sep .. pythonpath or "")
  env.MPLBACKEND = "module://iron_image_backend"

  return cmd, env
end

return python
