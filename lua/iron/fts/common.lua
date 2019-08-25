local fthelper = {
  functions = {},
  types = {}
}

local extend = function(tbl, itm)
  if itm == nil then
    return tbl
  end

  if type(itm) == "table" then
    for _, i in ipairs(itm) do
      table.insert(tbl, i)
    end
  else
    table.insert(tbl, itm)
  end

  return tbl
end

fthelper.functions.format = function(repldef, lines)
  assert(type(lines) == "table", "Supplied lines is not a table")

  if #lines == 1 then
    return lines
  end

  local new = {}
  extend(new, repldef.open)

  for _, v in ipairs(lines) do
    table.insert(new, v)
  end
  if repldef.close ~= nil then
    extend(new, repldef.close)
  elseif (#new > 0
      and new[#new] ~= ""
      and string.byte(string.sub(new[#new], 1, 1)) > 31) then
    table.insert(new, "")
  end

  return new
end

return fthelper
