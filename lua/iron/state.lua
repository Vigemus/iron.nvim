local config = require("iron.config")

local state = {
  repls = {},
  repl_open_cmd = nil,
}

function state.get_repl(ft)
  if ft == nil or ft == "" then
    error("Empty filetype")
  end

  return config.scope.get(state.repls, ft)
end

function state.set_repl(ft, meta)
  return config.scope.set(state.repls, ft, meta)
end

return state
