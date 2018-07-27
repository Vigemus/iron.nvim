local fthelper = {
  functions = {},
  types = {}
}

fthelper.functions.format = function(repldef, lines)
  local tp = fthelper.types[repldef.type or "plain"](repldef)
  local new = {}
  local off = 0

  if tp.open ~= nil then
    new = {tp.open}
    off = 1
  end

  for ix, v in ipairs(lines) do
    new[ix+off] = v
  end

  if tp.close ~= nil then
    new[#new+off] = tp.close
  end

  new[#new+off] = ''
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
