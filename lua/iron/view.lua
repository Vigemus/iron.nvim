-- luacheck: globals unpack vim
local view = {}

view.openfloat = function(config, buff)
  return vim.api.nvim_open_win(buff, false, config)
end

-- Deprecated
view.openwin = function(cmd, buff)
  vim.cmd(cmd)
  vim.api.nvim_set_current_buf(buff)

  local winid = vim.fn.bufwinid(buff)
  vim.api.nvim_win_set_option(winid, "winfixwidth", true)
  return winid
end

local function check_size(value, ...)
  if type(value) == "function" then
    return value(...)
  end
  return value
end

view.top = function(size, buff)
  local width = vim.o.columns
  size = check_size(size, buff)

  return view.openfloat({
    relative = "editor",
    width = width,
    height = size,
    row = 0,
    col = 0
  }, buff)
end

view.bottom = function(size, buff)
  local width = vim.o.columns
  local height = vim.o.lines
  size = check_size(size, buff)

  return view.openfloat({
    relative = "editor",
    width = width,
    height = size,
    row = height - size,
    col = 0,
  }, buff)
end

view.right = function(size, buff)
  local width = vim.o.columns
  local height = vim.o.lines
  size = check_size(size, buff)

  return view.openfloat({
    relative = "editor",
    width = size,
    height = height,
    row = 0,
    col = width - size
  }, buff)
end

view.left = function(size, buff)
  local height = vim.o.lines
  size = check_size(size, buff)

  return view.openfloat({
    relative = "editor",
    width = size,
    height = height,
    row = 0,
    col = 0
  }, buff)
end

view.center = function(size, buff)
  local width = vim.o.columns
  local height = vim.o.lines
  size = check_size(size, buff)

  return view.openfloat({
    relative = "editor",
    width = math.ceil(width * 0.5),
    height = size,
    row = math.ceil(height * 0.5) - math.ceil(size * 0.5),
    col = math.ceil(width * 0.25)
  }, buff)
end

view.curry = setmetatable({}, {
  __index = function(_, v)
    local originalfn = rawget(view, v)
    return function(size)
      return function(bufnr)
        return originalfn(size, bufnr)
      end
    end
  end
})


return view
