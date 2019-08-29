local extend = require("iron.util.tables").extend
local scala = {}

local def = function(command)
  return {
    command = command,
    format = function(lines)
      if #lines == 1 then
        return {lines[1]}
      end

      return extend(":paste", lines, "\04")
    end
  }
end

scala.sbt = def{"sbt"}
scala.scala = def{"scala"}

return scala
