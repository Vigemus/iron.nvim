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
      print("found")
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
    for line=2, #lines do
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

  for i, line in ipairs(lines) do
    table.insert(result, line)

    if i < #lines then
      local current_line_has_indent = string.match(line, "^%s") ~= nil
      local next_line_has_indent = string.match(lines[i + 1], "^%s") ~= nil

      if isWindows() then
        if not contains(config.repl_definition.python.command, "ipython") then
          if current_line_has_indent and not next_line_has_indent then
            table.insert(result, cr)
          end
        end
      else
        if current_line_has_indent and not next_line_has_indent then
          table.insert(result, cr)
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
