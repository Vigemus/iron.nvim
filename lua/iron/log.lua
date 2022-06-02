-- luacheck: globals vim
local log = {}

if vim.deprecate then
  log.deprecate = vim.deprecate
else
  log.deprecate = function(old, new, version, app)
    local message = [[%s is deprecated, use %s instead. See :h deprecated
This function will be removed in %s version %s]]

    error(string.format(message, old, new, app, version))
  end
end

return log
