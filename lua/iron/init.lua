-- luacheck: globals unpack vim

--[[ -> iron
-- Here is the complete iron API.
-- Below is a brief description of module separation:
--  -->> behavior:
--    Functions that alter iron's behavior and are set to be used
--    within configuration by the user
--
--  -->> store:
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
--    of managing store and config from the user.
--]]
local view = require("iron.view")

local ext = {
  repl = require("iron.fts.common").functions,
  strings = require("iron.util.strings"),
  tables = require("iron.util.tables"),
}
local iron = {
  namespace = vim.api.nvim_create_namespace("iron"),
  mark = { -- Arbitrary numbers
    save_pos = 20,
    send = 77,
    begin_last = 99, -- Deprecated
    end_last = 100 -- Deprecated
  },
  store = {},
  behavior = {
    scope = require("iron.scope"),
    visibility = require("iron.visibility")
  },
  ll = {},
  core = {},
  fts = require("iron.fts")
}
local defaultconfig = {
  visibility = iron.behavior.visibility.toggle,
  scope = iron.behavior.scope.path_based,
  preferred = {},
  repl_open_cmd = view.openwin('topleft vertical 100 split')
}

-- [[ Low-level ]]

iron.ll.get = function(ft)
  return iron.config.scope.get(iron.store, ft)
end

iron.ll.set = function(ft, fn)
  return iron.config.scope.set(iron.store, ft, fn)
end

iron.ll.get_buffer_ft = function(bufnr)
  local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  if ext.tables.get(iron.fts, ft) == nil then
    vim.api.nvim_err_writeln("There's no REPL definition for current filetype "..ft)
  else
    return ft
  end
end

iron.ll.get_preferred_repl = function(ft)
  local repl_definitions = iron.fts[ft]
  local preference = iron.config.preferred[ft]
  local repl_def = nil

  if preference ~= nil then
    repl_def = repl_definitions[preference]
  elseif repl_definitions ~= nil then
    for _, v in pairs(repl_definitions) do
      if vim.fn.executable(v.command[1]) == 1 then
        repl_def = v
        break
      end
    end
    if repl_def == nil then
      vim.api.nvim_err_writeln("Failed to locate REPL executable, aborting")
    end
  else
    vim.api.nvim_err_writeln("There's no REPL definition for current filetype "..ft)
  end
  return repl_def
end

iron.ll.new_repl_window = function(buff, ft)
  if type(iron.config.repl_open_cmd) == "function" then
    return iron.config.repl_open_cmd(buff, ft)
  else
    return view.openwin(iron.config.repl_open_cmd, buff)
  end
end

iron.ll.create_new_repl = function(ft, repl, new_win)
  -- make creation of new windows optional
  if new_win == nil then
    new_win = true
  end

  local winid
  local prevwin = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_create_buf(false, true)

  if new_win then
    winid = iron.ll.new_repl_window(bufnr, ft)
  else
    if iron.ll.get(ft) == nil then
      winid = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(winid, bufnr)
    else
      winid = iron.ll.get(ft).winid
    end
  end

  vim.api.nvim_set_current_win(winid)
  local job_id = vim.fn.termopen(repl.command)

  local inst = {
    bufnr = bufnr,
    job = job_id,
    repldef = repl,
    winid = winid
  }

  local timer = vim.loop.new_timer()
  timer:start(10, 0, vim.schedule_wrap(function()
      vim.api.nvim_set_current_win(prevwin)
    end))

  return iron.ll.set(ft, inst)
end

iron.ll.create_preferred_repl = function(ft, new_win)
    local repl = iron.ll.get_preferred_repl(ft)

    if repl ~= nil then
      return iron.ll.create_new_repl(ft, repl, new_win)
    end

    return nil
end

iron.ll.ensure_repl_exists = function(ft)
  local mem = iron.ll.get(ft)
  local created = false

  if mem == nil or vim.fn.bufname(mem.bufnr) == "" then
    mem = iron.ll.create_preferred_repl(ft)
    created = true
  end

  return mem, created
end

iron.ll.send_to_repl = function(ft, data)
  local dt = data

  if type(data) == "string" then
    dt = ext.strings.split(data, '\n')
  end

  local mem = iron.ll.get(ft)
  dt = ext.repl.format(mem.repldef, dt)

  local window = vim.fn.win_getid(vim.fn.bufwinnr(mem.bufnr))
  vim.api.nvim_win_set_cursor(window, {vim.api.nvim_buf_line_count(mem.bufnr), 0})

  local indent = ""
  for i, v in ipairs(dt) do
    if #v == 0 then
      dt[i] = indent
    else
      indent = string.match(v, '^(%s)') or ""
    end
  end
  vim.api.nvim_call_function('chansend', {mem.job, dt})
end

iron.ll.get_repl_ft_for_bufnr = function(bufnr)
  -- given a buffer number, tries to look up the corresponding
  -- filetype of the REPL
  -- If the corresponding buffer number does not exist or is not
  -- a REPL, then return nil
  local ft_found = nil
  for ft in pairs(iron.store) do
    local mem = iron.ll.get(ft)
    if mem ~= nil and bufnr == mem.bufnr then
      ft_found = ft
    end
  end
  return ft_found
end

-- [[ Low-level ]]

iron.core.repl_here = function(ft)
  -- first check if the repl for the current filetype already exists
  local mem = iron.ll.get(ft)
  local exists = not (mem == nil or vim.fn.bufname(mem.bufnr) == "")

  if exists then
    vim.api.nvim_set_current_buf(mem.bufnr)
  else
    -- the repl does not exist, so we have to create a new one,
    -- but in the current window
    mem = iron.ll.create_preferred_repl(ft, false)
  end

  return mem
end

iron.core.repl_restart = function()
  -- First, check if the cursor is on top or a REPL
  -- Then, start a new REPL of the same type and enter it into the window
  -- Afterwards, wipe out the old REPL buffer
  -- This is done without asking for confirmation, so user beware
  local bufnr_here = vim.fn.bufnr("%")
  local ft_here = iron.ll.get_repl_ft_for_bufnr(bufnr_here)
  local mem = nil

  if ft_here ~= nil then
    mem = iron.ll.create_preferred_repl(ft_here, false)
    -- created a new one, now have to kill the old one
    vim.api.nvim_command('bwipeout! ' .. bufnr_here)
  else
    local ft = vim.api.nvim_buf_get_option(bufnr_here, 'filetype')

    local mem = iron.ll.get(ft)
    local exists = not (mem == nil or
                        vim.fn.bufname(mem.bufnr) == "")

    if exists then
      -- Wipe the old REPL and then create a new one
      vim.api.nvim_command('bwipeout! ' .. mem.bufnr)
      mem, _ = iron.ll.ensure_repl_exists(ft)
      vim.api.nvim_command('wincmd p')
    else
      -- no repl found, so nothing to do
      vim.api.nvim_err_writeln('No repl found in current buffer; cannot restart')
    end
  end

  return mem
end

iron.core.repl_by_name = function(repl_name, ft)
  ft = ft or vim.bo.ft
  local repl = iron.fts[ft][repl_name]

  if repl == nil then
    vim.api.nvim_err_writeln('Repl definition of name "' .. repl_name .. '" not found for file type: '.. ft)
    return
  end

  return iron.ll.create_new_repl(ft, repl)
end

iron.core.repl_for = function(ft)
  local mem, created = iron.ll.ensure_repl_exists(ft)

  if not created then
    local showfn = function()
      return iron.ll.new_repl_window(mem.bufnr, ft)
    end
    iron.config.visibility(mem.bufnr, showfn)
  else
    vim.api.nvim_command('wincmd p')
  end

  return mem
end

iron.core.focus_on = function(ft)
  local mem = iron.ll.ensure_repl_exists(ft)

  local showfn = function()
    return iron.ll.new_repl_window(mem.bufnr, ft)
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

    local linenr = vim.api.nvim_win_get_cursor(0)[1] - 1
    local cur_line = vim.api.nvim_buf_get_lines(0, linenr, linenr + 1, 0)[1]
    local width = vim.fn.strwidth(cur_line)

    vim.api.nvim_buf_set_extmark(0, iron.namespace, linenr, 0, {
        id = iron.mark.send,
        end_line = linenr,
        end_col = width - 1
      })

    if width == 0 then return end

    iron.core.send(ft, cur_line)
  end
end

iron.core.send_chunk = function(mode, mtype)
  local bstart, bend, bdelta
  local ft = iron.ll.get_buffer_ft(0)

  if ft == nil then return end

  if mode == "visual" then
    bstart = "'<"
    bend = "'>"
    bdelta = 0
  else
    bstart = "'["
    bend = "']"
    bdelta = 1
  end

  -- getpos is 1-based
  -- extmark, getlines are 0-based

  local b_line, b_col = unpack(vim.fn.getpos(bstart),2,3)
  local e_line, e_col = unpack(vim.fn.getpos(bend),2,3)

  local lines = vim.api.nvim_buf_get_lines(0, b_line - 1, e_line, 0)

  local b_line_len = vim.fn.strwidth(lines[1])
  local e_line_len = vim.fn.strwidth(lines[#lines])

  b_col,e_col = unpack(mtype=='line' and { 0,e_line_len} or { b_col,e_col })

  --handle eol
  b_col = ( b_col > b_line_len ) and b_line_len or b_col
  e_col = ( e_col > e_line_len ) and e_line_len or e_col

  if #lines == 0 then return end

  if e_col > 1 then
    lines[#lines] = string.sub(lines[#lines], 1, e_col)
  end
  if b_col > 1 then
    lines[1] = string.sub(lines[1], b_col)
  end

  iron.core.send(ft, lines)

  local mark = vim.api.nvim_buf_get_extmark_by_id(0, iron.namespace, iron.mark.save_pos, {})

  if #mark ~= 0 then
    -- winrestview is 1-based
    vim.fn.winrestview({lnum = mark[1] + 1, col = mark[2] + 1})
    vim.api.nvim_buf_del_extmark(0, iron.namespace, iron.mark.save_pos)
  end

  vim.api.nvim_buf_set_extmark(
    0,
    iron.namespace,
    b_line - 1 - bdelta,
    b_col - 1,
    {
      id = iron.mark.send,
      end_line = e_line - 1,
      end_col = e_col,

    }
  )

end

iron.core.send_motion = function(mtype) iron.core.send_chunk("motion", mtype) end

iron.core.visual_send = function() iron.core.send_chunk("visual") end

iron.core.repeat_cmd = function()
  local ft = iron.ll.get_buffer_ft(0)
  if ft == nil then return end

  local b_line, b_col, e_line, e_col

  -- extmark is 0-based index
  b_line, b_col, details = unpack(vim.api.nvim_buf_get_extmark_by_id(0, iron.namespace, iron.mark.send, {details = true}))
  e_line = details.end_row
  e_col = details.end_col
  --e_line, e_col = unpack(vim.api.nvim_buf_get_extmark_by_id(0, iron.namespace, iron.mark.end_last, {}))

  local lines = vim.api.nvim_buf_get_lines(0, b_line, e_line + 1, 0)

  if b_col >= 1 then
    lines[1] = string.sub(lines[1], b_col + 1)
  end
  if e_col >= 1 then
    lines[#lines] = string.sub(lines[#lines], 1, e_col + 1)
  end

  iron.core.send(ft, lines)
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
    vim.api.nvim_err_writeln("There's no REPL definition for current filetype " .. ft)
  else
    for k, v in pairs(defs) do
      table.insert(lst, {k, v})
    end
  end

  return lst
end

-- [[ Setup ]] --
iron.config = ext.tables.clone(defaultconfig)

return iron
