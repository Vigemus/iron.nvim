-- luacheck: globals vim
local fts = require("iron.fts")

local providers = {}

--[[ TODO ensure there's a default provider

The user should configure default provider; if none provided, use `first_matching_binary`.

The user should also be allowed to set specific providers for specific languages
--]]

providers.first_matching_binary = function(ft)
  local repl_definitions = fts[ft]
  if not repl_definitions then
    error("No repl definition configured for " .. ft)
  end

  local repl_def

  for _, v in pairs(repl_definitions) do
    if vim.fn.executable(v.command[1]) == 1 then
      repl_def = v
      break
    end
  end

  if not repl_def then
    error("Couldn't find a binary available for " .. ft)
  end
  return repl_def
end

return providers
