-- luacheck: globals unpack vim
local floats = {}
floats.top = function(size)
  local width = vim.o.columns
  local height = vim.o.lines
  return {
    relative = "editor",
    width = width,
    height = size,
    row = 0,
    col = 0
  }
end

floats.bottom = function(size)
  local width = vim.o.columns
  local height = vim.o.lines
  return {
    relative = "editor",
    width = width,
    height = size,
    row = height - size,
    col = 0
  }
end

floats.right = function(size)
  local width = vim.o.columns
  local height = vim.o.lines
  return {
    relative = "editor",
    width = size,
    height = height,
    row = 0,
    col = width - size
  }
end

floats.left = function(size)
  local height = vim.o.lines
  return {
    relative = "editor",
    width = size,
    height = height,
    row = 0,
    col = 0
  }
end

floats.center = function(size)
  local width = vim.o.columns
  local height = vim.o.lines

  return {
    relative = "editor",
    width = math.ceil(width * 0.5),
    height = size,
    row = math.ceil(height * 0.5) - math.ceil(offset * 0.5),
    col = math.ceil(width * 0.25)
  }
end

return floats
