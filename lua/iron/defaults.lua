-- luacheck: globals vim
local view = require("iron.view")

--- Default configurations for iron.nvim
-- @table defaults set of default configs
-- @field scratch_repl When enabled, the repl buffer will be a scratch buffer [default=false]
local defaults = {
  highlight_last = "IronLastSent",
  visibility = require("iron.visibility").toggle,
  scope = require("iron.scope").path_based,
  scratch_repl = false,
  preferred = setmetatable({}, {
    __newindex = function(tbl, k, v)
      vim.api.nvim_err_writeln("iron: Setting preferred repl is deprecated.")
      vim.api.nvim_err_writeln("      Use `repl_definition` key instead supplying the complete repl definition")
      rawset(tbl, k, b)
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
        vim.api.nvim_err_writeln("Failed to locate REPL executable, aborting")
      else
        rawset(tbl, key, repl_def)
        return repl_def
      end
    end
  }),
  should_map_plug = true,
  repl_open_cmd = 'topleft vertical 100 split',
  namespace = namespace,
  mark = { -- Arbitrary numbers
    save_pos = 20,
    send = 77,
  },
  buflisted = false,
}

return setmetatable({
    _defaults = function() return vim.deepcopy(defaults) end
  }, {
  __newindex = function(_, _, _)
    vim.api.nvim_err_writeln("Don't alter default table. Change iron.config instead")
  end,
  __index = function(_, k)
    return defaults[k]
  end
})
