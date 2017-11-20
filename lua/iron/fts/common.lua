local clone = require("iron.functional").clone

local common = {
  format = function(open, close)
    local r = function(data)
      local new = {open}
      for ix, v in ipairs(data) do
        new[ix+1] = v
      end
      new[#new+1] = close
      new[#new+1] = ''
      return new
    end

    return r
  end
}

common.new = function(type)
  local inner = function(args)
    local data = clone(common.types[type])
    data.format = common.format(data.open, data.close)

    for k, v in pairs(args) do
      data[k] = v
    end

    return data
  end
  return inner
end

common.types = {}

common.types.bracketed = {
  open = '\x1b[200~',
  close = '\x1b[201~',
}

return common
