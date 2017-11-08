local py = {}


py.ipython = {
  command = 'ipython',
  format = function(data)
      local new = {'\x1b[200~'}
      for ix, v in ipairs(data) do
          new[ix+1] = v
      end
      new[#new+1] = '\x1b[201~'
      new[#new+1] = ''
      return new
  end
}


return py
