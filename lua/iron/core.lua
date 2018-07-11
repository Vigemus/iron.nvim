-- luacheck: globals unpack vim
local nvim = vim.api
local fts = require('iron.fts')
local core = {}

local get_from_memory = function(config, memory, ft)
  return config.memory_management.get(memory, ft)
end

local set_on_memory = function(config, memory, ft, fn)
  return config.memory_management.set(memory, ft, fn)
end

core.get_preferred_repl = function(config, ft)
  local repl = fts[ft]
  local repl_def = config.preferred[ft]
  if repl_def == nil then
    -- TODO Find a better way to select preferred repl
    for k, v in pairs(repl) do
      if os.execute('which ' .. k .. ' > /dev/null') == 0 then
        repl_def = v
        break
      end
    end
  end
  return repl_def
end

core.create_new_repl = function(config, ft)
  nvim.nvim_command(config.repl_open_cmd .. '| enew | set wfw | startinsert')
  local repl = core.get_preferred_repl(config, ft)
  local job_id = nvim.nvim_call_function('termopen', {{repl.command}})
  local buffer_id = nvim.nvim_call_function('bufnr', {'%'})
  return { job = job_id, buffer = buffer_id, definition = repl}
end

-- TODO split get_repl from get_or_create_repl
-- TODO create ensure repl exists which won't toggle/create new/whatever
core.get_repl = function(config, memory, ft)
  local mem = get_from_memory(config, memory, ft)
  local newfn = function() return core.create_new_repl(config, ft) end
  local showfn = function()
    nvim.nvim_command(config.repl_open_cmd .. '| b ' .. mem.buffer ..' | set wfw | startinsert')
  end
  if mem == nil then
    mem = set_on_memory(config, memory, ft, newfn)
  else
    config.visibility(mem.buffer, newfn, showfn)
  end
  return mem
end

return core
