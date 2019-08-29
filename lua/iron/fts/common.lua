local extend = require("iron.util.tables").extend
local fthelper = {
  functions = {},
  types = {}
}

fthelper.functions.format = function(repldef, lines)
  assert(type(lines) == "table", "Supplied lines is not a table")


  local new
  if repldef.format then
    return repldef.format(lines)
  elseif #lines == 1 then
    new = lines
  else
    new = extend(repldef.open, lines, repldef.close)
  end

  if #new > 0 then
    new[#new] = new[#new] .. "\13"
  end

  return new
end

return fthelper
