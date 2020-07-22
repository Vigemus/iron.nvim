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

local function echoerr(msg)
  nvim.nvim_command('echohl ErrorMsg')
  nvim.nvim_command('echomsg "'..msg..'"')
  nvim.nvim_command('echohl')
end

local ext = {
  repl = require("iron.fts.common").functions,
  strings = require("iron.util.strings"),
  tables = require("iron.util.tables"),
}
local iron = {
  namespace = vim.api.nvim_create_namespace("iron"),
  marks = {},
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
  last = {},
  fts = require("iron.fts")
}
local defaultconfig = {
  debug_level = iron.behavior.debug_level.fatal,
  visibility = iron.behavior.visibility.toggle,
  manager = iron.behavior.manager.path_based,
  preferred = {},
  repl_open_cmd = "topleft vertical 100 split"
}

-- [[ Low-level ]]

iron.ll.get_from_memory = function(ft)
  return iron.config.manager.get(iron.memory, ft)
end

iron.ll.set_on_memory = function(ft, fn)
  return iron.config.manager.set(iron.memory, ft, fn)
end

iron.ll.get_buffer_ft = function(bufnr)
  local ft = nvim.nvim_buf_get_option(bufnr, 'filetype')
  if ext.tables.get(iron.fts, ft) == nil then
    echoerr("There's no REPL definition for current filetype "..ft)
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
  elseif repl_definitions ~= nil then
    for _, v in pairs(repl_definitions) do
      if nvim.nvim_call_function('exepath', {v.command[1]}) ~= '' then
        repl_def = v
        break
      end
    end
    if repl_def == nil then
      echoerr("Failed to locate REPL executable, aborting")
    end
  else
    echoerr("There's no REPL definition for current filetype "..ft)
  end
  return repl_def
end

iron.ll.new_repl_window = function(buff)
  if type(iron.config.repl_open_cmd) == "function" then
    iron.config.repl_open_cmd(buff)
  else
    nvim.nvim_command(iron.config.repl_open_cmd .. '| ' .. buff .. ' | set wfw | startinsert')
  end
end

iron.ll.create_new_repl = function(ft, repl, new_win)
  -- make creation of new windows optional
  if new_win == nil then
    new_win = true
  end

  if new_win then
    iron.ll.new_repl_window("enew")
  else
    -- just want to open a new empty buffer, as termopen destroys the
    -- currently active buffer
    nvim.nvim_command('enew')
  end


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

iron.ll.create_preferred_repl = function(ft, new_win)
    if new_win == nil then
        new_win = true
    end
    local repl = iron.ll.get_preferred_repl(ft)
    if repl ~= nil then
      return iron.ll.create_new_repl(ft, repl, new_win)
    end
    return nil
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

  local window = vim.fn.win_getid(vim.fn.bufwinnr(mem.bufnr))
  vim.api.nvim_win_set_cursor(window, {vim.api.nvim_buf_line_count(mem.bufnr), 0})

  nvim.nvim_call_function('chansend', {mem.job, dt})
end

iron.ll.get_repl_ft_for_bufnr = function(bufnr)
  -- given a buffer number, tries to look up the corresponding
  -- filetype of the REPL
  -- If the corresponding buffer number does not exist or is not
  -- a REPL, then return nil
  local ft_found = nil
  for ft in pairs(iron.memory) do
    local mem = iron.ll.get_from_memory(ft)
    if mem ~= nil and bufnr == mem.bufnr then
      ft_found = ft
    end
  end
  return ft_found
end

-- [[ Low-level ]]

iron.core.repl_here = function(ft)
  -- first check if the repl for the current filetype already exists
  local mem = iron.ll.get_from_memory(ft)
  local exists = not (mem == nil or
                      nvim.nvim_call_function('bufname', {mem.bufnr}) == "")

  if exists then
    -- it exists so just activate the buffer in the current window
    nvim.nvim_command('b ' .. mem.bufnr)
  else
    -- the repl does not exist, so we have to create a new one,
    -- but in the current window
    mem = iron.ll.create_preferred_repl(ft, false)
  end

  return mem
end

iron.core.repl_restart = function()
  -- First, check if the cursor is on top or a REPL
  -- Then, start a new REPL of the same time and enter it into the window
  -- Afterwards, wipe out the old REPL buffer
  -- This is done without asking for confirmation, so user beware
  local bufnr_here = nvim.nvim_call_function('bufnr', {"%"})
  local ft_here = iron.ll.get_repl_ft_for_bufnr(bufnr_here)
  local mem = nil

  if ft_here ~= nil then
    mem = iron.ll.create_preferred_repl(ft_here, false)
    -- created a new one, now have to kill the old one
    nvim.nvim_command('bwipeout! ' .. bufnr_here)
  else

    local ft = nvim.nvim_buf_get_option(bufnr_here, 'filetype')

    local mem = iron.ll.get_from_memory(ft)
    local exists = not (mem == nil or
                        nvim.nvim_call_function('bufname', {mem.bufnr}) == "")

    if exists then
      -- Wipe the old REPL and then create a new one
      nvim.nvim_command('bwipeout! ' .. mem.bufnr)
      mem, _ = iron.ll.ensure_repl_exists(ft)
      nvim.nvim_command('wincmd p')
    else
      -- no repl found, so nothing to do
      echoerr ('No repl found in current buffer; cannot restart')
    end
  end

  return mem
end


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
    if #cur_line == 0 then return end

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

iron.core.send_motion = function(mtype)
  local ft = iron.ll.get_buffer_ft(0)
  if ft == nil then return end

  local b_line, b_col, e_line, e_col, _
  _, b_line, b_col = unpack(nvim.nvim_call_function("getpos", {"'["}))
  _, e_line, e_col = unpack(nvim.nvim_call_function("getpos", {"']"}))

  local lines = nvim.nvim_buf_get_lines(0, b_line - 1, e_line, 0)
  if #lines == 0 then return end
  if mtype == 'char' then
    lines[#lines] = string.sub(lines[#lines], 1, e_col)
    lines[1] = string.sub(lines[1], b_col)
  end

  iron.debug.ll.store{
    b_col = b_col,
    e_col = e_col,
    b_line = b_line,
    e_line = e_line,
    lines = lines,
    where = "send_motion",
    level = iron.behavior.debug_level.info
  }

  iron.ll.ensure_repl_exists(ft)
  iron.ll.send_to_repl(ft, lines)

  local mark = vim.api.nvim_buf_get_extmarks(0, iron.namespace, 0, -1, {})[1]
  vim.fn.winrestview({lnum = mark[2], col = mark[3]})
  vim.api.nvim_buf_del_extmark(0, iron.namespace, mark[1])

  iron.last.b_line = b_line
  iron.last.b_col = b_col
  iron.last.e_col = e_col
  iron.last.e_line = e_line
end

iron.core.visual_send = function()
  local ft = iron.ll.get_buffer_ft(0)
  if ft == nil then return end

  local b_line, b_col, e_line, e_col, _
  _, b_line, b_col = unpack(nvim.nvim_call_function("getpos", {"'<"}))
  _, e_line, e_col = unpack(nvim.nvim_call_function("getpos", {"'>"}))

  local lines = nvim.nvim_buf_get_lines(0, b_line - 1, e_line, 0)
  lines[#lines] = string.sub(lines[#lines], 1, e_col)
  lines[1] = string.sub(lines[1], b_col)

  iron.debug.ll.store{
    b_col = b_col,
    e_col = e_col,
    b_line = b_line,
    e_line = e_line,
    lines = lines,
    where = "visual_send",
    level = iron.behavior.debug_level.info
  }

  iron.ll.ensure_repl_exists(ft)
  iron.ll.send_to_repl(ft, lines)


-- [[ TODO: Add extmark]]
  iron.last.b_line = b_line
  iron.last.b_col = b_col
  iron.last.e_col = e_col
  iron.last.e_line = e_line
end

iron.core.repeat_cmd = function()
  local ft = iron.ll.get_buffer_ft(0)
  if ft == nil then return end

  local b_line, b_col, e_line, e_col
  b_line = iron.last.b_line
  b_col = iron.last.b_col
  e_line = iron.last.e_line
  e_col = iron.last.e_col

  local lines = nvim.nvim_buf_get_lines(0, b_line - 1, e_line, 0)
  lines[#lines] = string.sub(lines[#lines], 1, e_col)
  lines[1] = string.sub(lines[1], b_col)

  iron.debug.ll.store{
    b_col = b_col,
    e_col = e_col,
    b_line = b_line,
    e_line = e_line,
    lines = lines,
    where = "repeat_cmd",
    level = iron.behavior.debug_level.info
  }

  iron.ll.ensure_repl_exists(ft)
  iron.ll.send_to_repl(ft, lines)
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
    echoerr("There's no REPL definition for current filetype " .. ft)
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
  local inspect = require("vim.inspect")
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
    echoerr ("There's no REPL definition for current filetype " .. ft)
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
  local inspect = require("vim.inspect")
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
  print(require("vim.inspect")(defs))
end

iron.debug.memory = function()
  print(require("vim.inspect")(iron.memory))
end

-- [[ Setup ]] --
iron.config = ext.tables.clone(defaultconfig)

return iron
