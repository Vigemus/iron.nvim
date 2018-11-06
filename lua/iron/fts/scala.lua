local scala = {}

scala.sbt = {
  command = {"sbt"},
  open = ":paste\n",
  close = "\04",
}

scala.scala = {
  command = {"scala"},
  type = "custom",
  open = ":paste\n",
  close = "\04",
}

return scala
