-- luacheck: globals unpack vim
local curry2 = function(fn)
  return function(fst, snd)
    if snd ~= nil then
      return fn(fst, snd)
    end
    return function(new)
      return fn(fst, new)
    end
  end
end

local view =  {}

view.openfloat = function(config, buff)
  return vim.api.nvim_open_win(buff, false, config)
end

view.openwin = function(nvim_cmd, buff)
  vim.api.nvim_command(nvim_cmd)
  vim.api.nvim_set_current_buf(buff)

  local winid = vim.fn.win_getid(vim.fn.bufwinnr(buff))
  vim.api.nvim_win_set_option(winid, "winfixwidth", true)
  return winid
end


view.top = function(size, buff)
  local width = vim.o.columns

  return view.openfoat({
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

  return view.openfloat({
    relative = "editor",
    width = width,
    height = size,
    row = height - size,
    col = 0
  }, buff)
end

view.right = function(size, buff)
  local width = vim.o.columns
  local height = vim.o.lines

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

  return view.openfloat({
    relative = "editor",
    width = math.ceil(width * 0.5),
    height = size,
    row = math.ceil(height * 0.5) - math.ceil(size * 0.5),
    col = math.ceil(width * 0.25)
  }, buff)
end

return setmetatable({},
  {__index = function(_, key)
      return curry2(view[key])
   end})

