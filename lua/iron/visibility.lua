local nvim = vim.api -- luacheck: ignore
local visibility = {}

visibility.always_new = function(_, newfn, _)
    newfn()
end

visibility.single = function(bufid, newfn, showfn)
  local bufname = nvim.nvim_call_function('bufname', {bufid})
  if bufname == "" then
    newfn()
  else
    local window = nvim.nvim_call_function('bufwinnr', {bufid})
    if window == -1 then
      showfn()
    end
  end
end

visibility.toggle = function(bufid, newfn, showfn)
  local bufname = nvim.nvim_call_function('bufname', {bufid})
  if bufname == "" then
    newfn()
  else
    local window = nvim.nvim_call_function('bufwinnr', {bufid})
    if window == -1 then
      showfn()
    else
      nvim.nvim_command("exec '" .. window .. "wincmd c'")
    end
  end
end

return visibility
