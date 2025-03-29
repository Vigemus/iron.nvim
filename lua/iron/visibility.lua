-- luacheck: globals unpack vim
local visibility = {}

--- Show hidden window
-- Creates a window for a buffer if it was previously
-- hidden by nvim_win_hide, otherwise does nothing.
-- @return window handle
-- @treturn boolean wither the window was hidden or not
local show_hidden = function(bufid, showfn)
  local was_hidden = false
  local window = vim.fn.bufwinid(bufid)

  if window == -1 then
    was_hidden = true
    window = showfn()
  end

  return window, was_hidden
end

visibility.single = function(bufid, showfn)
  show_hidden(bufid, showfn)
end

visibility.toggle = function(bufid, showfn)
  local window, was_hidden = show_hidden(bufid, showfn)
  if not was_hidden then
    vim.api.nvim_win_hide(window)
  end
end

visibility.focus = function(bufid, showfn)
  local window = show_hidden(bufid, showfn)
  vim.api.nvim_set_current_win(window)
end

return visibility
