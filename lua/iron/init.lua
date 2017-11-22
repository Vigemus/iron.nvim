-- luacheck: globals unpack vim
local nvim = vim.api

local clone = require("iron.util.functional").clone
local visibility = require("iron.visibility")
local memory_management = require("iron.memory_management")

--[[ -> config proxy
-- enables seamless configuration either through
-- lua or neovim, prepending `iron_` to the key.
--]]
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

--[[ -> default config
-- Here is defined the default configuration of iron and minimal required data
-- iron expects to be set in order to correctly function.
--]]
local defaultconfig = {
  visibility = visibility.toggle,
  memory_management = memory_management.path_based,
  preferred = {}
}


--[[ -> new config
-- creates a new config based on the default config
-- and sets the proxy in it.
--]]
local new_config = function()
  local config = clone(defaultconfig)
  setmetatable(config, _nvim_proxy)

  return config
end


--[[ -> iron
-- Here is the complete iron API.
-- Below is a brief description of module separation:
--  -->> predefs:
--    Functions that alter iron's behavior and are set to be used
--    within configuration by the user
--
--  -->> memory:
--    Iron's repl database, so it knows which instances it's managing.
--
--  -->> core:
--    Repl management functions.
--
--  -->> config:
--    This is what guides irons behavior. Falls back to `g:iron_`
--    variables is value isn't set in lua.
--
--  -->> _ | api:
--    User api, should have all public functions there.
--    mostly a reorganization of core, hiding the complexity
--    of managing memory and config from the user.
--]]
local api = {}
local iron = {
  predefs = {
    visibility = visibility,
    memory_management = memory_management,
  },
  memory = {},
  core = require('iron.core'),
  config = new_config(),
  api = api,
  _ = api
}

--[[ -> set config
-- configuration entrypoint.
-- Below is a code example, setting the defaults:
--| iron._.set_config{
--|   visibility = iron.predefs.visibility.toggle,
--|   memory_management = iron.predefs.memory_management.path_based,
--| }
--]]
api.set_config = function(cfg)
  local config = new_config()

  for k, v in pairs(cfg) do
    config[k] = v
  end

  iron.config = config
end


--[[ -> repl for
-- opens a repl for given `ft`
-- Below is a code example, opening a new lua repl: 
--| iron._.repl_for('lua')
--]]
api.repl_for = function(ft)
  iron.core.get_repl(iron.config, iron.memory, ft)
end

api.send_to = function(ft, data)
  iron.core.send_to_repl(iron.config, iron.memory, ft, data)
end

return iron
