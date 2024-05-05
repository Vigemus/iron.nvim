local checks = {}

checks.isWindows = function()
    return package.config:sub(1,1) == '\\'
end

return checks
