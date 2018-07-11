-- luacheck: globals unpack vim
local nvim = vim.api


--[[ -> iron
-- Here is the complete iron API.
-- Below is a brief description of module separation:
--  -->> behavior:
--    Functions that alter iron's behavior and are set to be used
--    within configuration by the user
--
--  -->> memory:
--    Iron's repl database, so it knows which instances it's managing.
--
--  -->> ll:
--    Low level functions that interact with neovim's windows and buffers.
--
--  -->> config:
--    This is what guides irons behavior. Falls back to `g:iron_`
--    variables is value isn't set in lua.
--
--  -->> fts:
--    File types and their repl definitions.
--
--  -->> utils:
--    Utility functions that can be reused by clients.
--
--  -->> core:
--    User api, should have all public functions there.
--    mostly a reorganization of core, hiding the complexity
--    of managing memory and config from the user.
--]]
local helpers = {
  ft = require("iron.fts.common")
}
local iron = {
  memory = {},
  behavior = {
    manager = require("iron.memory_management"),
    visibility = require("iron.visibility")
  },
  ll = {},
  core = {},
  debug = {},
  fts = require("iron.fts"),
  utils = require("iron.utils")
}

local defaultconfig = {
  visibility = iron.behavior.visibility.toggle,
  manager = iron.behavior.manager.path_based,
  preferred = {},
  repl_open_cmd = "topleft vertical 100 split"
}

iron.ll.get_from_memory = function(ft)
  return iron.config.manager.get(iron.memory, ft)
end

iron.ll.set_on_memory = function(ft, fn)
  return iron.config.manager.set(iron.memory, ft, fn)
end

iron.ll.get_file_ft = function()
  return nvim.nvim_get_option("ft")
end

iron.ll.get_repl_definitions = function(ft)
  return iron.fts[ft]
end

iron.ll.get_preferred_repl = function(ft)
  local repl = iron.ll.get_repl_definitions(ft)
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

iron.ll.new_repl_window = function(buff)
  nvim.nvim_command(iron.config.repl_open_cmd .. '| ' .. buff .. ' | set wfw | startinsert')
end

iron.ll.create_new_repl = function(ft, repl)
  iron.ll.new_repl_window("enew")
  local job_id = nvim.nvim_call_function('termopen', {{repl.command}})
  local bufnr = nvim.nvim_call_function('bufnr', {'%'})
  local inst = {
    bufnr = bufnr,
    job = job_id,
    repldef = repl
  }
  iron.ll.set_on_memory(ft, function() return inst end)

  return bufnr
end

iron.ll.send_to_repl = function(ft, data)
  local mem = iron.ll.get_from_memory(ft)
  nvim.nvim_call_function('jobsend', {mem.job, helpers.ft.functions.format(mem.repldef, data)})
end

iron.core.repl_for = function(ft)
  local mem = iron.ll.get_from_memory(ft)
  local newfn = function()
    local repl = iron.ll.get_preferred_repl(ft)
    iron.ll.create_new_repl(ft, repl)
  end
  local showfn = function()
    iron.ll.new_repl_window('b ' .. mem)
  end

  if mem == nil then
    newfn()
  else
    iron.config.visibility(mem.bufnr, newfn, showfn)
  end

  return iron.ll.get_from_memory(ft)
end

iron.core.focus_on = function(ft)
  local mem = iron.ll.get_from_memory(ft)

  if mem == nil then
    mem = iron.core.repl_for(ft)
  end

  iron.behavior.visibility.focus(mem, nil, nil)

  return mem
end


iron.core.set_config = function(cfg)
  iron.config = iron.utils.clone(defaultconfig)
  for k, v in pairs(cfg) do
    iron.config[k] = v
  end
end

iron.core.add_repl_definitions = function(defns)
  for ft, defn in pairs(defns) do
    if iron.fts[ft] == nil then
      iron.fts[ft] = {}
    end
    for repl, repldfn in pairs(defn) do
      iron.fts[ft][repl] = repldfn
    end
  end
end

iron.debug.fts = function()
  print(require("inspect")(iron.fts))
end

iron.debug.memory = function()
  print(require("inspect")(iron.memory))
end

-- [[ Setup ]] --
iron.config = iron.utils.clone(defaultconfig)

return iron
