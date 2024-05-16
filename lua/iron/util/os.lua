local checks = {}

checks.is_windows = function()
    return package.config:sub(1,1) == '\\'
end


checks.has = function(feature)
  return vim.api.nvim_call_function('has', {feature}) == 1
end

return checks
