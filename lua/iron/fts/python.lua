local extend = require("iron.util.tables").extend
local python = {}

local format = function(open, close)
  return function(lines)
    local new = {
      open .. lines[1]
    }

    for line=2, #lines do
      table.insert(new, lines[line])
    end

    return extend(new, close)
  end

end

local def = function(cmd)
  return {
    command = cmd,
    format = format("\27[200~", "\27[201~\13")
  }
end

python.ptipython = def({"ptipython"})
python.ipython = def({"ipython", "--no-autoindent"})
python.ptpython = def({"ptpython"})
python.python = {
  command = {"python"},
  close = {""}
}

return python
