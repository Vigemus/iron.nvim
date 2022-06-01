-- luacheck: globals vim
local fns = {}

fns.extend = function(...)
  local tbl = {}
  local tbls = {n = select("#", ...), ...}
  for ix=1, tbls.n do
    local itm = tbls[ix]
    if itm ~= nil then
      if type(itm) == "table" then
        vim.list_extend(tbl, itm)
      else
        table.insert(tbl, itm)
      end
    end
  end

  return tbl
end


return fns
