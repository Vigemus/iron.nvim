local extend = require("iron.util.tables").extend
local scala = {}

scala.sbt = {
  command = {"sbt"},
  format = function(lines)
  if #lines == 1 then
    return lines
  end

  return extend({":paste"}, lines, {"\04"})
end
}

scala.scala = {
  command = {"scala"},
  type = "custom",
  open = ":paste\n",
  close = "\04",
}

return scala
