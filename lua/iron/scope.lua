-- luacheck: globals vim
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
    local tab = vim.fn.tabpagenr()
    default_map_set(memory, ft, "tab_" .. tab, repl_data)
    return repl_data
  end,
  get = function(memory, ft)
    ensure_key(memory, ft)
    local tab = vim.fn.tabpagenr()
    return memory[ft]["tab_" .. tab]
  end
}

scope.path_based = {
  set = function(memory, ft, repl_data)
    local pwd = vim.fn.getcwd()
    default_map_set(memory, ft, "pwd_" .. pwd, repl_data)
    return repl_data
  end,
  get = function(memory, ft)
    ensure_key(memory, ft)
    local pwd = vim.fn.getcwd()
    return memory[ft]["pwd_" .. pwd]
  end
}

scope.singleton = {
  set = function(memory, ft, repl_data)
    ensure_key(memory, ft)
    default_map_set(memory, ft, "singleton", repl_data)
    return repl_data
  end,
  get = function(memory, ft)
    ensure_key(memory, ft)
    return memory[ft]["singleton"]
  end
}

return scope
