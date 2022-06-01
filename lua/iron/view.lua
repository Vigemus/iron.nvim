-- luacheck: globals unpack vim
local view = {}

--- Private functions
local nested_modifier

local with_nested_metatable = function(tbl)
  return setmetatable(tbl, {
    __index = nested_modifier,
    __call = function(_, arg)
      return tbl:mode(arg)
    end
  })
end

nested_modifier = function(tbl, key)
  local new = vim.deepcopy(tbl)
  table.insert(new, key)

  return with_nested_metatable(new)
end

local size_extractor = function(size, vertical, ...)
  local new_size
  if type(size) == "string" and string.find(size, "%%") then
    local pct = size:gsub("%%", "")
    pct = tonumber(pct)
    local base
    if vertical then
      base = vim.o.columns
    else
      base = vim.o.lines
    end
    new_size = math.floor((base * pct) / 100.0)
  elseif type(size) == "function" then
    new_size = size(...)
  elseif size == nil then
    new_size = 0
  else
    new_size = size
  end
  return new_size
end

view.helpers = {}

--- Returns proportional difference between an object and the editor size
-- with the offset adjusting the distance on both sides.
-- Use offset 0.5 for centralization
-- @tparam string attr Either "lines" or "columns"
-- @tparam number offset proportion of distribution (0.5 is centralized)
-- @tparam number sz size of the object
-- @treturn number placement index
-- @treturn function
view.helpers.proportion = function(attr, offset)
  return function(sz)
    return math.ceil(vim.o[attr] * offset - sz * offset)
  end
end

view.helpers.relative = function(attr, offset)
  return function(sz)
    return math.ceil(vim.o[attr] - sz - offset)
  end
end

view.helpers.difference = function(attr)
  return function(sz)
    return math.ceil(vim.o[attr]  - sz)
  end
end


--- Open a split window
-- Takes the arguments to the split command as nested values (keys) of this table.
-- @example view.split.vertical.botright(20)
-- @tparam table data itself
-- @tparam number|string|function size Either a number, a size in string or a function that returns the size
-- @tparam number bufnr buffer handle
-- @treturn number window id
-- @treturn function the function that opens the window
view.split = with_nested_metatable{ mode = function(data, size)
  return function(bufnr)
    local args = vim.list_slice(data, 1, #data)
    local new_size = size_extractor(size, vim.tbl_contains(data, "vertical") or vim.tbl_contains(data, "vert"))

    if size then
      table.insert(args, tostring(new_size))
    end
    table.insert(args, "split")

    vim.cmd(table.concat(args, " "))
    vim.api.nvim_set_current_buf(bufnr)

    local winid = vim.fn.bufwinid(bufnr)
    vim.api.nvim_win_set_option(winid, "winfixwidth", true)
    vim.api.nvim_win_set_option(winid, "winfixheight", true)
    return winid
  end
end
}

--- Used to open a float window
-- @tparam table config parameters for the float window
-- @tparam number buff buffer handle
-- @treturn number window id
view.openfloat = function(config, buff)
  return vim.api.nvim_open_win(buff, false, config)
end

view.offset = function(opts)
  return function()
    local new_w_size = size_extractor(opts.width, true)
    local new_h_size = size_extractor(opts.height, false)
    local new_w_offset = size_extractor(opts.w_offset, true, new_w_size)
    local new_h_offset = size_extractor(opts.h_offset, false, new_h_size)

    return {
      relative = "editor",
      width = new_w_size,
      height = new_h_size,
      row = new_h_offset,
      col = new_w_offset
    }
  end
end

view.top = function(size)
  return view.offset{width = vim.o.columns, height = size}
end

view.bottom = function(size)
  return view.offset{width = vim.o.columns, height = size, h_offset = view.helpers.difference("lines")}
end

view.right = function(size)
  return view.offset{width = size, height = vim.o.lines, w_offset = view.helpers.difference("columns")}
end

view.left = function(size)
  return view.offset{width = size, height = vim.o.lines}
end

view.center = function(w_size, h_size)
  return view.offset{
    width = w_size,
    height = h_size,
    w_offset = view.helpers.proportion("width", 0.5),
    h_offset = view.helpers.proportion("height", 0.5)
  }
end


view.curry = setmetatable({}, {
  __index = function(_, key)
    if  view[key] == nil then
      error("Function `view." .. key .. "` does not exist.")
    end
    vim.deprecate("view.curry.key" .. key, "view." .. key, "3.2", "iron.nvim")
    return view[key]
  end
})

return view
