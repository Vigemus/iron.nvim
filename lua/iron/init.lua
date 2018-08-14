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
--  -->> core:
--    User api, should have all public functions there.
--    mostly a reorganization of core, hiding the complexity
--    of managing memory and config from the user.
--]]
local ext = {
  repl = require("iron.fts.common").functions,
  strings = require("iron.util.strings"),
  tables = require("iron.util.tables"),
  functions = require("iron.util.functions")
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
  fts = require("iron.fts")
}
local defaultconfig = {
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

  if type(data) == string then
    dt = ext.strings.split(data, '\n')
  end

  local mem = iron.ll.get_from_memory(ft)
  nvim.nvim_call_function('chansend', {mem.job, ext.repl.format(mem.repldef, dt)})
end
-- Low-level ]]

iron.core.repl_for = function(ft)
  local mem, created = iron.ll.ensure_repl_exists(ft)

  if not created then
    local showfn = function()
      iron.ll.new_repl_window('b ' .. mem.bufnr)
    end
    iron.config.visibility(mem.bufnr, showfn)
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
  iron.config = ext.functions.clone(defaultconfig)
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

iron.core.send_motion = function(tp)
  local bufnr = nvim.nvim_call_function('bufnr', {'%'})
  local ft = iron.ll.get_buffer_ft(bufnr)

  if ft ~= nil then
    local b_line, b_col, e_line, e_col, _

    if tp == 'visual' then
      _, b_line, b_col = unpack(nvim.nvim_call_function("getpos", {"v"}))
      _, e_line, e_col = unpack(nvim.nvim_call_function("getpos", {"."}))

      b_col = b_col - 1
      e_col = e_col - 1
    else
      b_line, b_col = unpack(nvim.nvim_buf_get_mark(bufnr, '['))
      e_line, e_col = unpack(nvim.nvim_buf_get_mark(bufnr, ']'))
    end

    local lines = nvim.nvim_buf_get_lines(bufnr, b_line - 1, e_line, 0)

    lines[1] = string.sub(lines[1], b_col + 1)

    if b_line ~= e_line then
      lines[#lines] = string.sub(lines[#lines], 1, e_col + 1)
    else
      lines[#lines] = string.sub(lines[#lines], 1, e_col - b_col + 1)
    end

    iron.ll.ensure_repl_exists(ft)
    iron.ll.send_to_repl(ft, lines)
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
iron.config = ext.functions.clone(defaultconfig)

return iron
