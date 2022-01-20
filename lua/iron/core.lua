-- luacheck: globals vim unpack
local fts = require("iron.fts")
local ll = require("iron.lowlevel")
local focus = require("iron.visibility").focus
local config = require("iron.config")
local marks = require("iron.marks")
local tables = require("iron.util.tables")

local core = {}

--- Creates a repl in the current window
-- @param ft the filetype of the repl to be created
core.repl_here = function(ft)
  return ll.if_repl_exists(ft, function(mem)
    vim.api.nvim_set_current_buf(mem.bufnr)
    return mem
  end,
  function()
    local repl = ll.get_repl_def(ft)
    local meta = ll.create_repl_on_current_window(repl)
    ll.set(ft, meta)

    return meta
  end)
end


--- Restarts the repl for the current buffer
-- First, check if the cursor is on top or a REPL
-- Then, start a new REPL of the same type and enter it into the window
-- Afterwards, wipe out the old REPL buffer
-- This is done without asking for confirmation, so user beware
-- TODO Split into "restart a repl" and "do X for current buffer's repl"
core.repl_restart = function()
  local bufnr_here = vim.fn.bufnr("%")
  local ft = ll.get_repl_ft_for_bufnr(bufnr_here)

  if ft ~= nil then
    local repl = ll.get_repl_def(ft)
    local meta = ll.create_repl_on_current_window(repl)
    ll.set(ft, meta)

    -- created a new one, now have to kill the old one
    vim.api.nvim_buf_delete(bufnr_here, {force = true})
    return meta
  else
    ft = vim.bo[bufnr_here].filetype

    return ll.if_repl_exists(ft, function(mem)
      local replwin = vim.fn.bufwinid(mem.bufnr)
      local currwin = vim.api.nvim_get_current_win()

      local repl = ll.get_repl_def(ft)

      if replwin == nil or replwin == -1 then
        replwin = ll.new_window()
      else
        vim.api.nvim_set_current_win(replwin)
      end

      local meta = ll.create_repl_on_current_window(repl)
      ll.set(ft, meta)

      vim.api.nvim_set_current_win(currwin)
      vim.api.nvim_buf_delete(mem.bufnr, {force = true})

      return meta
      end, function()
      -- no repl found, so nothing to do
      vim.api.nvim_err_writeln('No repl found in current buffer; cannot restart')
    end)
  end
end

core.repl_by_name = function(repl_name, ft)
  vim.api.nvim_err_writeln("iron: repl_by_name is deprecated.")
  ft = ft or vim.bo.ft
  local repl = fts[ft][repl_name]

  if repl == nil then
    vim.api.nvim_err_writeln('Repl definition of name "' .. repl_name .. '" not found for file type: '.. ft)
    return
  end

  return ll.create_new_repl(ft, repl)
end

core.repl_for = function(ft)
  return ll.if_repl_exists(ft, function(mem)
    config.visibility(mem.bufnr, function()
           local winid = ll.new_window()
           vim.api.nvim_win_set_buf(winid, mem.bufnr)
           return winid
        end)
        return mem
    end, function()
      local currwin = vim.api.nvim_get_current_win()
      local replwin = ll.new_window()
      local repl = ll.get_repl_def(ft)

      vim.api.nvim_set_current_win(replwin)
      local meta = ll.create_repl_on_current_window(repl)
      ll.set(ft, meta)

      vim.api.nvim_set_current_win(currwin)
      return meta
    end)
end

core.focus_on = function(ft)
  return ll.if_repl_exists(ft, function(mem)
    focus(mem.bufnr, function()
           local winid = ll.new_window()
           vim.api.nvim_win_set_buf(winid, mem.bufnr)
           return winid
        end)
        return mem
    end,
    function()
      local replwin = ll.new_window()
      local repl = ll.get_repl_def(ft)

      vim.api.nvim_set_current_win(replwin)
      local meta = ll.create_repl_on_current_window(repl)
      ll.set(ft, meta)

      return meta
    end)
end

-- TODO Move away/deprecate
core.set_config = function(cfg)
  for k, v in pairs(cfg) do
    require("iron.config")[k] = v
  end
end

core.add_repl_definitions = function(defns)
  vim.api.nvim_err_writeln("iron: `add_repl_definitions` is deprecated")
  vim.api.nvim_err_writeln("      Use `core.setup{repl_definition = {<ft> = {<definition>}}}`")
  for ft, defn in pairs(defns) do
    if fts[ft] == nil then
      fts[ft] = {}
    end
    for repl, repldfn in pairs(defn) do
      fts[ft][repl] = repldfn
    end
  end
end

core.send = function(ft, data)
  ll.ensure_repl_exists(ft)
  ll.send_to_repl(ft, data)
end

core.send_line = function()
  local ft = ll.get_buffer_ft(0)

  if ft ~= nil then

    local linenr = vim.api.nvim_win_get_cursor(0)[1] - 1
    local cur_line = vim.api.nvim_buf_get_lines(0, linenr, linenr + 1, 0)[1]
    local width = vim.fn.strwidth(cur_line)

    if width == 0 then return end

    marks.set{
      from_line = linenr,
      from_col = 0,
      to_line = linenr,
      to_col = width - 1
    }

    core.send(ft, cur_line)
  end
end

core.send_chunk = function(mode, mtype)
  local bstart, bend
  local ft = ll.get_buffer_ft(0)

  if ft == nil then return end

  if mode == "visual" then
    bstart = "'<"
    bend = "'>"
  else
    bstart = "'["
    bend = "']"
  end

  local b_line, b_col = unpack(vim.fn.getpos(bstart),2,3)
  local e_line, e_col = unpack(vim.fn.getpos(bend),2,3)

  local lines = vim.api.nvim_buf_get_lines(0, b_line - 1, e_line, 0)

  if #lines == 0 then return end

  local b_line_len = vim.fn.strwidth(lines[1])
  local e_line_len = vim.fn.strwidth(lines[#lines])

  b_col, e_col = unpack(mtype=='line' and { 0, e_line_len } or { b_col, e_col })

  --handle eol
  b_col = ( b_col > b_line_len ) and b_line_len or b_col
  e_col = ( e_col > e_line_len ) and e_line_len or e_col

  if e_col > 1 then
    lines[#lines] = string.sub(lines[#lines], 1, e_col)
  end
  if b_col > 1 then
    lines[1] = string.sub(lines[1], b_col)
  end

  marks.set{
    from_line = b_line - 1,
    from_col = math.max(b_col - 1, 0),
    to_line = e_line - 1,
    to_col = e_col - 1
  }

  core.send(ft, lines)

  marks.winrestview()
end

core.send_motion = function(mtype) core.send_chunk("motion", mtype) end

core.visual_send = function() core.send_chunk("visual") end

core.repeat_cmd = function()
  local ft = ll.get_buffer_ft(0)
  if ft == nil then return end

  local pos = marks.get()

  if pos == nil then return end

  local lines = vim.api.nvim_buf_get_lines(0, pos.from_line, pos.to_line + 1, 0)

  if #lines == 1 then
    if pos.from_col >= 1 or pos.to_col < string.len(lines[1]) - 1 then
      lines[1] = string.sub(lines[1], pos.from_col + 1, pos.to_col + 1)
    end
  else
    if pos.from_col >= 1 then
      lines[1] = string.sub(lines[1], pos.from_col + 1)
    end
    if pos.to_col < string.len(lines[#lines]) - 1 then
      lines[#lines] = string.sub(lines[#lines], 1, pos.to_col + 1)
    end
  end

  core.send(ft, lines)
end

-- TODO Remove from core, make it public elsewhere
core.list_fts = function()
  local lst = {}

  for k, _ in pairs(fts) do
    table.insert(lst, k)
  end

  return lst
end

-- TODO Remove from core, make it public elsewhere
core.list_definitions_for_ft = function(ft)
  local lst = {}
  local defs = fts[gt]

  if defs == nil then
    vim.api.nvim_err_writeln("There's no REPL definition for current filetype " .. ft)
  else
    for k, v in pairs(defs) do
      table.insert(lst, {k, v})
    end
  end

  return lst
end


return core
