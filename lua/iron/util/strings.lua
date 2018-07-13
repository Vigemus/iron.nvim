local strings = {}

strings.split = function(str, sep)
   local fields = {}
   local pattern = string.format("([^%s]+)", sep)
   str:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

return strings
