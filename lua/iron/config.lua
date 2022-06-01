-- luacheck: globals vim
local view = require("iron.view")

--- Default values
--@module config
local config

--- Default configurations for iron.nvim
-- @table config.values
-- @tfield false|string highlight_last Either false or the name of a highlight group
-- @field scratch_repl When enabled, the repl buffer will be a scratch buffer
-- @field should_map_plug when enabled iron will provide its mappings as `<plug>(..)` as well,
-- for backwards compatibility
-- @field close_window_on_exit closes repl window on process exit
local values = {
  highlight_last = "IronLastSent",
  visibility = require("iron.visibility").toggle,
  scope = require("iron.scope").path_based,
  scratch_repl = false,
  close_window_on_exit = true,
  preferred = setmetatable({}, {
    __newindex = function(tbl, k, v)
      vim.deprecate("config.preferred", "config.repl_definition", "3.1", "iron.nvim")
      rawset(tbl, k, v)
    end
  }),
  repl_definition = setmetatable({}, {
    __index = function(tbl, key)
      local repl_definitions = require("iron.fts")[key]
      local repl_def
      for _, v in pairs(repl_definitions) do
        if vim.fn.executable(v.command[1]) == 1 then
          repl_def = v
          break
        end
      end
      if repl_def == nil then
        error("Failed to locate REPL executable, aborting")
      else
        rawset(tbl, key, repl_def)
        return repl_def
      end
    end
  }),
  should_map_plug = false,
  repl_open_cmd = view.curry.bottom(40),
  mark = { -- Arbitrary numbers
    save_pos = 20,
    send = 77,
  },
  buflisted = false,
}

-- HACK for LDoc to correctly link @see annotations
config = vim.deepcopy(values)
config.values = values

return config
