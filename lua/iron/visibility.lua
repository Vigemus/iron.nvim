local nvim = vim.api -- luacheck: ignore
local visibility = {}

local hidden = function(bufid, showfn)
  local was_hidden = false
  local window = nvim.nvim_call_function('bufwinnr', {bufid})

  if window == -1 then
    showfn()
    was_hidden = true
    window = nvim.nvim_call_function('bufwinnr', {bufid})
  end

  return window, was_hidden
end

visibility.single = function(bufid, showfn)
  hidden(bufid, showfn)
end

visibility.toggle = function(bufid, showfn)
  local window, was_hidden = hidden(bufid, showfn)
  if not was_hidden then
    nvim.nvim_command(window .. "wincmd c")
  else
    nvim.nvim_command(window .. "wincmd p")
  end
end

visibility.focus = function(bufid, showfn)
  local window = hidden(bufid, showfn)
  nvim.nvim_command(window .. "wincmd w")
end

return visibility
