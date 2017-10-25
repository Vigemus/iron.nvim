-- luacheck: globals unpack vim
local nvim = vim.api
local iron = {
  memory = {},
  core = {
    visibility = require("iron.visibility")
  },
  config = {},
  fts = require("iron.fts.fts")
}

local defaultconfig = {
  visibility = iron.core.visibility.toggle,
  preferred = {}
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
  local preference = iron.config.preferred[ft]
  local repl_def = nil
  if preference ~= nil then
    repl_def = repl[preference]
  else
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
  nvim.nvim_call_function('termopen', {{repl.command}})
  iron.memory[ft] = nvim.nvim_call_function('bufnr', {'%'})
end

iron.core.get_repl_instance = function(ft)
  local mem = iron.memory[ft]
  local newfn = function()
    iron.core.create_new_repl(ft)
  end
  local showfn = function()
    nvim.nvim_command(iron.config.repl_open_cmd .. '| b ' .. mem ..' | set wfw | startinsert')
  end

  if mem == nil then
    newfn()
  else
    iron.config.visibility(mem, newfn, showfn)
  end
end

iron.set_config = function(cfg)
  iron.config = copy(defaultconfig)
  setmetatable(iron.config, _nvim_proxy)
  for k, v in pairs(cfg) do
    iron.config[k] = v
  end
end

return iron
