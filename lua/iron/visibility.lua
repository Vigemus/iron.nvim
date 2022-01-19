-- luacheck: globals unpack vim
local visibility = {}

local hidden = function(bufid, showfn)
  local was_hidden = false
  local window = vim.fn.bufwinid(bufid)

  if window == -1 then
    was_hidden = true
    window = showfn()
  end

  return window, was_hidden
end

visibility.single = function(bufid, showfn)
  hidden(bufid, showfn)
end

visibility.toggle = function(bufid, showfn)
  local window, was_hidden = hidden(bufid, showfn)
  if not was_hidden then
    vim.api.nvim_win_hide(window)
  else
    vim.api.nvim_set_current_win(window)
  end
end

visibility.focus = function(bufid, showfn)
  local window = hidden(bufid, showfn)
    vim.api.nvim_set_current_win(window)
end

return visibility
