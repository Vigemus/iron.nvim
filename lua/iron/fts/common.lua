local fthelper = {
  functions = {},
  types = {}
}

fthelper.functions.format = function(repldef, lines)
  local tp = fthelper.types[repldef.type or "plain"]
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


fthelper.types.plain = {
  open = nil,
  close = nil,
}

fthelper.types.bracketed = {
  open = '\x1b[200~',
  close = '\x1b[201~',
}

return fthelper
