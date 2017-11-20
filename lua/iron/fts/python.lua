local common = require('iron.fts.common')
local py = {}


py.ipython = common.new("bracketed"){
  command = 'ipython'
}

return py
