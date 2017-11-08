-- luacheck: globals unpack vim
local clone = function(curr)
  local new = {}
  for k, v in pairs(curr) do
    new[k] = v
  end

  return new
end

local visibility = require("iron.visibility")

local defaultconfig = {
  visibility = visibility.toggle,
  preferred = {}
}


local nvim = vim.api
local iron = {
  memory = {},
  core = {
    visibility = visibility
  },
  config = clone(defaultconfig),
  fts = require("iron.fts.fts")
}

local _nvim_proxy = {
  __index = function(_, key)
    local key_ = 'iron_' .. key
    local val = nil
    if nvim.nvim_call_function('exists', {key_}) == 1 then
      val = nvim.nvim_get_var(key_)
    end
    return val
  end
}

setmetatable(iron.config, _nvim_proxy)

iron.core.get_file_ft = function()
  return nvim.nvim_get_option("ft")
end

iron.core.get_repl_definitions = function(ft)
  return iron.fts[ft]
end

iron.core.get_preferred_repl = function(ft)
  local repl = iron.core.get_repl_definitions(ft)
  local repl_def = iron.config.preferred[ft]
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

iron.core.create_new_repl = function(ft)
  nvim.nvim_command(iron.config.repl_open_cmd .. '| enew | set wfw | startinsert')
  local repl = iron.core.get_preferred_repl(ft)
  local job_id = nvim.nvim_call_function('termopen', {{repl.command}})
  local buffer_id = nvim.nvim_call_function('bufnr', {'%'})
  iron.memory[ft] = { job = job_id, buffer = buffer_id, definition = repl}
end

iron.core.get_repl_instance = function(ft)
  local mem = iron.memory[ft]
  local newfn = function()
    iron.core.create_new_repl(ft)
  end
  local showfn = function()
    nvim.nvim_command(iron.config.repl_open_cmd .. '| b ' .. mem.buffer ..' | set wfw | startinsert')
  end

  if mem == nil then
    newfn()
  else
    iron.config.visibility(mem.buffer, newfn, showfn)
  end
end

iron.set_config = function(cfg)
  iron.config = clone(defaultconfig)
  setmetatable(iron.config, _nvim_proxy)

  for k, v in pairs(cfg) do
    iron.config[k] = v
  end
end

return iron
