local scala = {}

scala.sbt = {
  command = "sbt",
  type = "custom",
  open = ":paste\n",
  close = "",
}

scala.scala = {
  command = "scala",
  type = "custom",
  open = ":paste\n",
  close = "",
}

return scala
