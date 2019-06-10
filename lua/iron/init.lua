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
--    This is what guides irons behavior.
--
--  -->> fts:
--    File types and their repl definitions.
--
--  -->> core:
--    User api, should have all public functions there.
--    mostly a reorganization of core, hiding the complexity
--    of managing memory and config from the user.
--]]
local ext = {
  repl = require("iron.fts.common").functions,
  strings = require("iron.util.strings"),
  tables = require("iron.util.tables"),
}
local iron = {
  memory = {},
  behavior = {
    debug_level = require("iron.debug_level"),
    manager = require("iron.memory_management"),
    visibility = require("iron.visibility")
  },
  ll = {},
  core = {},
  debug = {
    ll = {},
    mem = {}
  },
  fts = require("iron.fts")
}
local defaultconfig = {
  debug_level = iron.behavior.debug_level.fatal,
  visibility = iron.behavior.visibility.toggle,
  manager = iron.behavior.manager.path_based,
  preferred = {},
  repl_open_cmd = "topleft vertical 100 split"
}

-- [[ Low-level
iron.ll.get_from_memory = function(ft)
  return iron.config.manager.get(iron.memory, ft)
end

iron.ll.set_on_memory = function(ft, fn)
  return iron.config.manager.set(iron.memory, ft, fn)
end

iron.ll.get_buffer_ft = function(bufnr)
  local ft = nvim.nvim_buf_get_option(bufnr, 'filetype')
  if ext.tables.get(iron.fts, ft) == nil then
    nvim.nvim_command("echoerr 'No repl definition for current files &filetype'")
  else
    return ft
  end
end

iron.ll.get_file_ft = function()
  return nvim.nvim_get_option("ft")
end

iron.ll.get_repl_definitions = function(ft)
  return iron.fts[ft]
end

iron.ll.get_preferred_repl = function(ft)
  local repl_definitions = iron.ll.get_repl_definitions(ft)
  local preference = iron.config.preferred[ft]
  local repl_def = nil

  if preference ~= nil then
    repl_def = repl_definitions[preference]
  else
    for _, v in pairs(repl_definitions) do
      if nvim.nvim_call_function('exepath', {v.command[1]}) ~= '' then
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
  local job_id = nvim.nvim_call_function('termopen', {repl.command})
  local bufnr = nvim.nvim_call_function('bufnr', {'%'})
  local inst = {
    bufnr = bufnr,
    job = job_id,
    repldef = repl
  }
  iron.ll.set_on_memory(ft, function() return inst end)

  return inst
end

iron.ll.create_preferred_repl = function(ft)
    local repl = iron.ll.get_preferred_repl(ft)
    return iron.ll.create_new_repl(ft, repl)
end

iron.ll.ensure_repl_exists = function(ft, newfn)
  newfn = newfn or iron.ll.create_preferred_repl
  local mem = iron.ll.get_from_memory(ft)
  local created = false

  if mem == nil or nvim.nvim_call_function('bufname', {mem.bufnr}) == "" then
    mem = newfn(ft)
    created = true
  end

  return mem, created
end

iron.ll.send_to_repl = function(ft, data)
  local dt = data

  if type(data) == "string" then
    dt = ext.strings.split(data, '\n')
  end

  local mem = iron.ll.get_from_memory(ft)
  dt = ext.repl.format(mem.repldef, dt)

  iron.debug.ll.store{
    where = "send_to_repl",
    raw_lines = data,
    lines = dt,
    repl = mem,
    level = iron.behavior.debug_level.info
  }

  local window = nvim.nvim_call_function('bufwinnr', {mem.bufnr})
  if window ~= -1 then
    nvim.nvim_command(window .. "windo normal! G")
    nvim.nvim_command(window .. "wincmd p")
  end
  nvim.nvim_call_function('chansend', {mem.job, dt})
end
-- Low-level ]]

iron.core.repl_for = function(ft)
  local mem, created = iron.ll.ensure_repl_exists(ft)

  if not created then
    local showfn = function()
      iron.ll.new_repl_window('b ' .. mem.bufnr)
    end
    iron.config.visibility(mem.bufnr, showfn)
  else
    nvim.nvim_command('wincmd p')
  end

  return mem
end

iron.core.focus_on = function(ft)
  local mem = iron.ll.ensure_repl_exists(ft)

  local showfn = function()
    iron.ll.new_repl_window('b ' .. mem.bufnr)
  end

  iron.behavior.visibility.focus(mem.bufnr, showfn)

  return mem
end

iron.core.set_config = function(cfg)
  iron.config = ext.tables.clone(defaultconfig)
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

iron.core.send = function(ft, data)
  iron.ll.ensure_repl_exists(ft)
  iron.ll.send_to_repl(ft, data)
end

iron.core.send_line = function()
  local ft = iron.ll.get_buffer_ft(0)

  if ft ~= nil then
    local linenr = nvim.nvim_win_get_cursor(0)[1]
    local cur_line = nvim.nvim_buf_get_lines(0, linenr-1, linenr, 0)[1]

    iron.debug.ll.store{
      linenr = linenr,
      cur_line = cur_line,
      where = "send_line",
      level = iron.behavior.debug_level.info
    }

    iron.ll.ensure_repl_exists(ft)
    iron.ll.send_to_repl(ft, cur_line)
  end
end

iron.core.send_motion = function(tp)
  local ft = iron.ll.get_buffer_ft(0)

  if ft ~= nil then
    local b_line, b_col, e_line, e_col, _

    if tp == 'visual' then
      _, b_line, b_col = unpack(nvim.nvim_call_function("getpos", {"v"}))
      _, e_line, e_col = unpack(nvim.nvim_call_function("getpos", {"."}))

      b_col = b_col - 1
      e_col = e_col - 1

      -- swap locations if visual selection beginning is after ending
      if b_line > e_line then
          b_line, b_col, e_line, e_col = e_line, e_col, b_line, b_col
      elseif b_line == e_line and b_col > e_col then
          b_col, e_col = e_col, b_col
      end
    else
      b_line, b_col = unpack(nvim.nvim_buf_get_mark(0, '['))
      e_line, e_col = unpack(nvim.nvim_buf_get_mark(0, ']'))
    end

    local lines = nvim.nvim_buf_get_lines(0, b_line - 1, e_line, 0)
    local nosub = nvim.nvim_buf_get_lines(0, b_line - 1, e_line, 0)

    if b_col ~= 0 then
      lines[1] = string.sub(lines[1], b_col + 1)
    end

    if e_col ~= 0 then
      if b_line ~= e_line then
        lines[#lines] = string.sub(lines[#lines], 1, e_col + 1)
      else
        lines[#lines] = string.sub(lines[#lines], 1, e_col - b_col + 1)
      end
    end

  iron.debug.ll.store{
    b_col = b_col,
    e_col = e_col,
    b_line = b_line,
    e_line = e_line,
    lines = lines,
    lines_nosub = nosub,
    tp = tp,
    where = "send_motion",
    level = iron.behavior.debug_level.info
  }


    iron.ll.ensure_repl_exists(ft)
    iron.ll.send_to_repl(ft, lines)
  end
end

iron.core.list_fts = function()
  local lst = {}

  for k, _ in pairs(iron.fts) do
    table.insert(lst, k)
  end

  return lst
end

iron.core.list_definitions_for_ft = function(ft)
  local lst = {}
  local defs = ext.tables.get(iron.fts, ft)

  if defs == nil then
    nvim.nvim_command("echoerr 'No repl definition for current filetype" .. ft .. "'")
  else
    for k, v in pairs(defs) do
      table.insert(lst, {k, v})
    end
  end

  return lst
end

iron.debug.ll.store = function(opt)
  opt.level = opt.level or iron.behavior.debug_level.info
  if opt.level > iron.config.debug_level then
    table.insert(iron.debug.mem, opt)
  end
end

iron.debug.dump = function(level, to_buff)
  level = level or iron.behavior.debug_level.info
  local inspect = require("inspect")
  local dump

  if to_buff then
    nvim.nvim_command("rightbelow vertical edit +set\\ nobl\\ bh=delete\\ bt=nofile iron://debug-logs")
    dump = function(data)
      nvim.nvim_call_function("writefile", {{data}, "iron://debug-logs"})
    end
  else
    dump = function(data)
      print(inspect(data))
    end

  end

  for _, v in ipairs(iron.debug.mem) do
    if v.level <= level then
      dump(v)
    end
  end

end

iron.core.list_fts = function()
  local lst = {}

  for k, _ in pairs(iron.fts) do
    table.insert(lst, k)
  end

  return lst
end

iron.core.list_definitions_for_ft = function(ft)
  local lst = {}
  local defs = ext.tables.get(iron.fts, ft)

  if defs == nil then
    nvim.nvim_command("echoerr 'No repl definition for current filetype" .. ft .. "'")
  else
    for k, v in pairs(defs) do
      table.insert(lst, {k, v})
    end
  end

  return lst
end

iron.debug.ll.store = function(opt)
  opt.level = opt.level or iron.behavior.debug_level.info
  if opt.level > iron.config.debug_level then
    table.insert(iron.debug.mem, opt)
  end
end

iron.debug.dump = function(level, to_buff)
  level = level or iron.behavior.debug_level.info
  local inspect = require("inspect")
  local dump

  if to_buff then
    nvim.nvim_command("rightbelow vertical edit +set\\ nobl\\ bh=delete\\ bt=nofile iron://debug-logs")
    dump = function(data)
      nvim.nvim_call_function("writefile", {{data}, "iron://debug-logs"})
    end
  else
    dump = function(data)
      print(inspect(data))
    end

  end

  for _, v in ipairs(iron.debug.mem) do
    if v.level <= level then
      dump(v)
    end
  end

end

iron.debug.definitions = function(lang)
  local defs = lang and iron.fts[lang] or iron.fts
  print(require("inspect")(defs))
end

iron.debug.memory = function()
  print(require("inspect")(iron.memory))
end

-- [[ Setup ]] --
iron.config = ext.tables.clone(defaultconfig)

return iron
