-- luacheck: globals vim
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

return category
