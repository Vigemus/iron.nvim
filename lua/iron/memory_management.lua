local nvim = vim.api -- luacheck: ignore
local memory_management = {}

local ensure_key = function(map, key)
  map[key] = map[key] or {}
end

local default_map_set = function(map, base, key, value)
  ensure_key(map, base)
  map[base][key] = value
end

memory_management.tab_based = {
  set = function(memory, ft, creation)
    local repl_data = creation()
    local tab = nvim.nvim_call_function('tabpagenr')
    default_map_set(memory, ft, "tab_" .. tab, repl_data)
    return repl_data
  end,
  get = function(memory, ft)
    ensure_key(memory, ft)
    local tab = nvim.nvim_call_function('tabpagenr')
    return memory[ft]["tab_" .. tab]
  end
}

memory_management.path_based = {
  set = function(memory, ft, creation)
    local repl_data = creation()
    local pwd = nvim.nvim_call_function('getcwd')
    default_map_set(memory, ft, "pwd_" .. pwd, repl_data)
    return repl_data
  end,
  get = function(memory, ft)
    ensure_key(memory, ft)
    local pwd = nvim.nvim_call_function('getcwd')
    return memory[ft]["pwd_" .. pwd]
  end
}

memory_management.singleton = {
  set = function(memory, ft, creation)
    local repl_data = creation()
    ensure_key(memory, ft)
    memory[ft] = repl_data
    return repl_data
  end,
  get = function(memory, ft)
    return memory[ft]
  end
}

return memory_management
