local fthelper = {
  functions = {},
  types = {}
}

fthelper.functions.format = function(repldef, lines)
  local tp = fthelper.types[repldef.type or "plain"](repldef)
  local new = {}

  if tp.open ~= nil then
    new = table.insert(tp.open)
  end

  for _, v in ipairs(lines) do
    table.insert(new, v)
  end

  if tp.close ~= nil then
    table.insert(new, tp.close)
  elseif (#new > 0
      and new[#new] ~= ""
      and string.byte(string.sub(new[#new], 1, 1)) > 31) then
    table.insert(new, "")
  end

  return new
end

fthelper.types.plain = function(_)
  return {
    open = nil,
    close = nil,
  }
end

fthelper.types.bracketed = function(_)
  return {
    open = '\x1b[200~',
    close = '\x1b[201~',
  }
end

fthelper.types.custom = function(def)
  return {
    open = def.open,
    close = def.close,
  }
end

return fthelper
