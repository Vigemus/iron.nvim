local config = require("iron.config")
local isWindows = require("iron.util.os").isWindows
local extend = require("iron.util.tables").extend
local open_code = "\27[200~"
local close_code = "\27[201~"
local cr = "\13"

local common = {}


local contains = function(table, substring)
  for _, v in ipairs(table) do
    if string.find(v, substring) then
      return true
    end
  end
  return false
end


common.format = function(repldef, lines)
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
    if not isWindows() then
      new[#new] = new[#new] .. cr
    end
  end

  return new
end

common.bracketed_paste = function(lines)
  if #lines == 1 then
    return { lines[1] .. cr }
  else
    local new = { open_code .. lines[1] }
    for line = 2, #lines do
      table.insert(new, lines[line])
    end

    table.insert(new, close_code .. cr)

    return new
  end
end


--- @param lines table  "each item of the table is a new line to send to the repl"
--- @return table  "returns the table of lines to be sent the the repl with
-- the return carriage '\r' added"
common.bracketed_paste_python = function(lines)
  local result = {}
  
  local newlines = {}
  for _, line in pairs(lines) do
    if string.len(line) > 0 then
      table.insert(newlines, line)
    end
  end
  lines = newlines

  local function startsWithException(s)
    local exceptions = { "elif", "else", "except", "finally", "#" }
    for _, exception in ipairs(exceptions) do
      local pattern0 = "^" .. exception .. "[%s:]"
      local pattern1 = "^" .. exception .. "$"
      if string.match(s, pattern0) or string.match(s, pattern1) then
        return true
      end
    end
    return false
  end

  local indent_open = false
  for i, line in ipairs(lines) do
    if string.match(line, "^%s") ~= nil then
      indent_open = true
    end

    table.insert(result, line)

    if i < #lines then
      local isIpython = contains(config.repl_definition.python.command, "ipython")

      if isWindows() and not isIpython or not isWindows() then
        if i < #lines then
          if indent_open and string.match(lines[i + 1], "^%s") == nil then
            if not startsWithException(lines[i + 1]) then
              indent_open = false
              table.insert(result, cr)
            end
          end
        end
      end

    end
  end

  if not isWindows() then
    table.insert(result, cr)
  end

  return result
end


return common
