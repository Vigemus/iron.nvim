local str = require("iron.util.strings")
local category = {}

category.as = function(obj, desired_type)
  return function(mappings)
    local obj_type = type(obj)
    if obj_type == desired_type then
      return obj
    else
      return mappings[obj_type][desired_type](obj)
    end
  end
end


sm = setmetatable
function infix(f)
  local mt = { __sub = function(self, b) return f(self[1], b) end }
  return sm({}, { __sub = function(a, _) return sm({ a }, mt) end })
end

return category
