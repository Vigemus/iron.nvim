local fns = {}

fns.keys = function(tbl)
    local new = {}
    for k, _ in pairs(tbl) do
        table.insert(new, k)
    end
    return new
end

fns.values = function(tbl)
    local new = {}
    for _, v in pairs(tbl) do
        table.insert(new, v)
    end
    return new
end

fns.peek = function(tbl)
  local _, v = next(tbl)
  return v
end

fns.get = function(d, k)
  return d and d[k]
end

fns.get_in = function(d, k)
  local p = d
  for _, i in ipairs(k) do
    p = fns.get(p, i)
  end

  return p
end
return fns
