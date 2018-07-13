local fns = {}

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

fns.chain = function(fnl, ...)
  local arg = {...}
  for _, fn in ipairs(fnl) do
    fn(table.unpack(arg))
  end
end

fns.cchain = function(fnl)
  return function(...)
    return fns.chain(fnl, ...)
  end
end

return fns
