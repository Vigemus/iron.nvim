local python = {}

local def = function(cmd)
  return {
  command = cmd,
    open = "\27[200~",
    close = {"\27[201~", "", ""},
  }
end

python.ptipython = def("ptipython")
python.ipython = def("ipython")
python.ptpython = def("ptpython")
python.python = def("python")

return python
