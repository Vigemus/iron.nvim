local fns = {}

fns.keys = function(tbl)
    local new = {}
    if tbl ~= nil then
      for k, _ in pairs(tbl) do
          table.insert(new, k)
      end
    end
    return new
end

fns.values = function(tbl)
    local new = {}
    if tbl ~= nil then
      for _, v in pairs(tbl) do
          table.insert(new, v)
      end
    end
    return new
end

fns.peek = function(tbl)
  local _, v = next(tbl)
  return v
end

fns.get = function(d, k)
  if type(d) == "table" then
    return d and d[k]
  else
    return nil
  end
end

fns.get_in = function(d, k)
  local p = d
  for _, i in ipairs(k) do
    p = fns.get(p, i)
  end

  return p
end

fns.clone = function(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[fns.clone(orig_key)] = fns.clone(orig_value)
        end
        setmetatable(copy, fns.clone(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

fns.merge = function (...)
  local res = {}
  for _, tbl in ipairs({...}) do
    for k, v in pairs(tbl) do
      res[k] = v
    end
  end
  return res
end

fns.extend = function(...)
  local tbl = {}
  local tbls = {n = select("#", ...), ...}
  for ix=1, tbls.n do
    local itm = tbls[ix]
    if itm ~= nil then

      if type(itm) == "table" then
        for _, i in ipairs(itm) do
          table.insert(tbl, i)
        end
      else
        table.insert(tbl, itm)
      end

    end
  end

  return tbl
end


return fns
