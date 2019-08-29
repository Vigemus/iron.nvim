local extend = require("iron.util.tables").extend
local fthelper = {
  functions = {},
  types = {}
}

fthelper.functions.format = function(repldef, lines)
  assert(type(lines) == "table", "Supplied lines is not a table")

  if repldef.format then
    return repldef.format(lines)
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
