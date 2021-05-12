local scala = {}

local def = function(command)
  return {
    command = command,
    open = ":paste",
    close = "\04"
  }
end

scala.sbt = def{"sbt"}
scala.scala = def{"scala"}

return scala
