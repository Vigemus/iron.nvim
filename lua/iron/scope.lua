local nvim = vim.api -- luacheck: ignore
local scope = {}

local ensure_key = function(map, key)
  map[key] = map[key] or {}
end

local default_map_set = function(map, base, key, value)
  ensure_key(map, base)
  map[base][key] = value
end

scope.tab_based = {
  set = function(memory, ft, repl_data)
    local tab = nvim.nvim_call_function('tabpagenr', {})
    default_map_set(memory, ft, "tab_" .. tab, repl_data)
    return repl_data
  end,
  get = function(memory, ft)
    ensure_key(memory, ft)
    local tab = nvim.nvim_call_function('tabpagenr', {})
    return memory[ft]["tab_" .. tab]
  end
}

scope.path_based = {
  set = function(memory, ft, repl_data)
    local pwd = nvim.nvim_call_function('getcwd', {})
    default_map_set(memory, ft, "pwd_" .. pwd, repl_data)
    return repl_data
  end,
  get = function(memory, ft)
    ensure_key(memory, ft)
    local pwd = nvim.nvim_call_function('getcwd', {})
    return memory[ft]["pwd_" .. pwd]
  end
}

scope.singleton = {
  set = function(memory, ft, repl_data)
    ensure_key(memory, ft)
    memory[ft] = repl_data
    return repl_data
  end,
  get = function(memory, ft)
    return memory[ft]
  end
}

return scope
