-- luacheck: globals vim
--- Loads iron's Python helper (python/iron_image/) into python and
-- ipython REPLs through the REPL's startup module (iron_image/startup/),
-- which then installs library integrations as they get imported.
local is_windows = require("iron.util.os").is_windows

---@class iron.image.PythonLang : iron.image.Lang
local python = {}

--- Directory holding the bundled Python helper package
---@return string
local helper_dir = function()
  local paths =
    vim.api.nvim_get_runtime_file("python/iron_image/__init__.py", false)
  if #paths == 0 then
    error("python/iron_image/__init__.py not found in runtimepath", 0)
  end
  return vim.fn.fnamemodify(paths[1], ":h:h")
end

--- PYTHONPATH with the helper package dir in front
---@param pythonpath string?
---@return string
local with_helper = function(pythonpath)
  local sep = is_windows() and ";" or ":"
  pythonpath = pythonpath or ""
  return helper_dir() .. (pythonpath ~= "" and sep .. pythonpath or "")
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
    table.insert(cmd, "--ext=iron_image.startup.ipython")
  else
    -- Python runs a single PYTHONSTARTUP file: ours, which then runs the
    -- user's own one
    local user_startup = env.PYTHONSTARTUP or vim.env.PYTHONSTARTUP
    if user_startup and user_startup ~= "" then
      env.IRON_PYTHONSTARTUP = user_startup
    end
    env.PYTHONSTARTUP = helper_dir() .. "/iron_image/startup/python.py"
  end

  env.PYTHONPATH = with_helper(env.PYTHONPATH or vim.env.PYTHONPATH)

  return cmd, env
end

--- Opens a pickled matplotlib figure in a window (iron_image.viewer), run
-- by the Python of the repl that made it
---@param path string interactive file
---@param dir string the repl's image dir
---@param fallback fun(reason: string)
---@return boolean handled
python.open = function(path, dir, fallback)
  if not vim.endswith(path, ".pickle") then
    return false
  end

  local file = io.open(dir .. "/python")
  local interpreter = file and file:read("*l")
  if file then
    file:close()
  end
  if not interpreter or interpreter == "" then
    fallback("the repl did not record its python")
    return true
  end

  local stderr = {}
  local job = vim.fn.jobstart(
    { interpreter, "-m", "iron_image.viewer", path },
    {
      env = { PYTHONPATH = with_helper(vim.env.PYTHONPATH) },
      -- Keep the window open after Neovim exits
      detach = true,
      on_stderr = function(_, data)
        vim.list_extend(stderr, data)
      end,
      on_exit = function(_, code)
        if code ~= 0 then
          local reason =
            vim.trim(table.concat(stderr, "\n")):gsub("^iron: ", "")
          fallback(reason ~= "" and reason or ("viewer exited with " .. code))
        end
      end,
    }
  )
  if job <= 0 then
    fallback("cannot run " .. interpreter)
  end
  return true
end

return python
