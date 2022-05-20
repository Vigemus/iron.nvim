-- luacheck: globals vim unpack

local fts = require("iron.fts")
local ll = require("iron.lowlevel")
local focus = require("iron.visibility").focus
local config = require("iron.config")
local marks = require("iron.marks")

--- Core functions of iron
-- @module core
local core = {}

--- Local helpers for creating a new repl.
-- Should be used by core functions, but not
-- exposed to the end-user
-- @local
local new_repl = {}

--- Create a new repl on the current window
-- Simple wrapper around the low level functions
-- Useful to avoid rewriting the get_def + create + save pattern
-- @param ft filetype
-- @param bufnr buffer to be used. Will be created if nil.
-- @return saved snapshot of repl metadata
new_repl.create = function(ft, bufnr)
  local repl = ll.get_repl_def(ft)
  if bufnr == nil then
    bufnr = ll.new_buffer()
  end
  local meta = ll.create_repl_on_current_window(ft, repl, bufnr)
  ll.set(ft, meta)

  return meta
end

--- Create a new repl on a new repl window
-- Adds a layer on top of @{new_repl.create},
-- ensuring it is created on a new window
-- @param ft filetype
-- @return saved snapshot of repl metadata
new_repl.create_on_new_window = function(ft)
  local bufnr = ll.new_buffer()
  local replwin = ll.new_window(bufnr)

  vim.api.nvim_set_current_win(replwin)
  local meta = new_repl.create(ft, bufnr)

  return meta
end

--- Creates a repl in the current window
-- @param ft the filetype of the repl to be created
-- @treturn table metadata of the repl
core.repl_here = function(ft)
  local meta = ll.get(ft)
  if ll.repl_exists(meta) then
    vim.api.nvim_set_current_buf(meta.bufnr)
    return meta
  else
    return new_repl.create(ft)
  end
end

--- Restarts the repl for the current buffer
-- First, check if the cursor is on top or a REPL
-- Then, start a new REPL of the same type and enter it into the window
-- Afterwards, wipe out the old REPL buffer
-- This is done without asking for confirmation, so user beware
-- @todo Split into "restart a repl" and "do X for current buffer's repl"
-- @return saved snapshotof repl metadata
core.repl_restart = function()
  local bufnr_here = vim.fn.bufnr("%")
  local ft = ll.get_repl_ft_for_bufnr(bufnr_here)

  if ft ~= nil then
    local meta = new_repl.create(ft)

    -- created a new one, now have to kill the old one
    vim.api.nvim_buf_delete(bufnr_here, {force = true})
    return meta
  else
    ft = ll.get_buffer_ft(0)

    local meta = ll.get(ft)
    if ll.repl_exists(meta) then
      local replwin = vim.fn.bufwinid(meta.bufnr)
      local currwin = vim.api.nvim_get_current_win()
      local new_meta

      if replwin == nil or replwin == -1 then
        new_meta = new_repl.create_on_new_window(ft)
      else
        vim.api.nvim_set_current_win(replwin)
        new_meta = new_repl.create(ft)
      end

      vim.api.nvim_set_current_win(currwin)
      vim.api.nvim_buf_delete(meta.bufnr, {force = true})

      return new_meta
    else
      vim.api.nvim_err_writeln('No repl found in current buffer; cannot restart')
    end
  end
end

--- Sends a close request to the repl
-- if @{config.values.close_window_on_exit} is set to true,
-- all windows associated with that repl will be closed.
-- Otherwise, this will only finish the process.
-- @param ft filetype
core.close_repl = function(ft)
  ft = ft or ll.get_buffer_ft(0)
  local meta = ll.get(ft)

  ll.send_to_repl(meta, string.char(04))
end

--- Creates a repl for a given filetype
-- It should open a new repl on a new window for the filetype
-- supplied as argument.
-- @param ft filetype
core.repl_for = function(ft)
  local meta = ll.get(ft)
  if ll.repl_exists(meta) then
    config.visibility(meta.bufnr, function()
      local winid = ll.new_window(meta.bufnr)
      vim.api.nvim_win_set_buf(winid, meta.bufnr)
      return winid
    end)
    return meta
  else
    local currwin = vim.api.nvim_get_current_win()
    meta = new_repl.create_on_new_window(ft)
    vim.api.nvim_set_current_win(currwin)
    return meta
  end
end

--- Moves to the repl for given filetype
-- When it doesn't exist, a new repl is created
-- directly moving the focus to it.
-- @param ft filetype
core.focus_on = function(ft)
  local meta = ll.get(ft)
  if ll.repl_exists(meta) then
    focus(meta.bufnr, function()
      local winid = ll.new_window(meta.bufnr)
      vim.api.nvim_win_set_buf(winid, meta.bufnr)
      return winid
    end)
    return meta
  else
    return new_repl.create_on_new_window(ft)
  end
end

--- [Deprecated] Sets configuration
-- Sets the configuration.
-- This is only a fraction of the actual setup and should not be directly used
-- @see core.setup
core.set_config = function(cfg)
  for k, v in pairs(cfg) do
    config[k] = v
  end
end

--- [Deprecated] adds repls definition to the set of configurations
-- Adds a repl definition to the collection of known repls.
-- It should not be used since this is a complicated way of configuring
-- the user experience.
-- @see core.setup
core.add_repl_definitions = function(defns)
  vim.api.nvim_err_writeln("iron: The function `add_repl_definitions` is deprecated")
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

--- Sends data to the repl
-- This is a top-level wrapper over the low-level
-- functions. It should send data to the repl, ensuring
-- it exists.
-- @param ft filetype (will be inferred if not supplied)
-- @tparam string|table data data to be sent to the repl.
core.send = function(ft, data)
  ft = ft or ll.get_buffer_ft(0)
  if data == nil then return end
  -- If the repl doesn't exist, it will be created
  local meta = ll.get(ft)

  if not ll.repl_exists(meta) then
    meta = core.repl_for(ft)
  end
  ll.send_to_repl(meta, data)
end

--- Sends the line under the cursor to the repl
-- Builds upon @{core.send}, extracting
-- the data beforehand.
core.send_line = function()
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

  core.send(nil, cur_line)
end

-- TODO Move out to separate ns
core.get_visual_selection = function()
  -- HACK Break out of visual mode
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', false, true, true), 'nx', false)
  local b_line, b_col
  local e_line, e_col

  local mode = vim.fn.visualmode()

  b_line, b_col = unpack(vim.fn.getpos("'<"),2,3)
  e_line, e_col = unpack(vim.fn.getpos("'>"),2,3)

  if e_line < b_line or (e_line == b_line and e_col < b_col) then
    e_line, b_line = b_line, e_line
    e_col, b_col = b_col, e_col
  end

  local lines = vim.api.nvim_buf_get_lines(0, b_line - 1, e_line, 0)

  if #lines == 0 then return end

  if mode == "\22" then
    for ix, line in ipairs(lines) do
      lines[ix] = string.sub(line, math.max(1, b_col), math.min(e_col, vim.fn.strwidth(line)))
    end
  elseif mode == "v" then
    local last = #lines
    -- Questionable whether we should do this here...
    lines[1] = string.sub(lines[1], math.min(b_col, vim.fn.strwidth(lines[1])))
    lines[last] = string.sub(lines[last], 1, math.min(e_col, vim.fn.strwidth(lines[last])))
  end

  marks.set{
    from_line = b_line - 1,
    from_col = math.max(b_col - 1, 0),
    to_line = e_line - 1,
    to_col = math.min(e_col, vim.fn.strwidth(lines[#lines])) - 1 -- TODO Check whether this is actually true
  }

  return lines
end

core.get_motion_selection = function(mtype)
  local b_line, b_col
  local e_line, e_col

  b_line, b_col = unpack(vim.fn.getpos("'["),2,3)
  e_line, e_col = unpack(vim.fn.getpos("']"),2,3)

  local lines = vim.api.nvim_buf_get_lines(0, b_line - 1, e_line, 0)
  if #lines == 0 then return end

  if mtype=='line' then
    b_col, e_col = 0, vim.fn.strwidth(lines[#lines])
  else
    b_col = math.max(b_col, vim.fn.strwidth(lines[1]))
    e_col = math.max(e_col, vim.fn.strwidth(lines[#lines]))
  end

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

  return lines

end

--- Sends a chunk of text from a motion to the repl
-- It is a simple wrapper over @{core.get_motion_selection}
-- in which the data is extracted by that function and sent to the repl.
-- @{core.send} will handle the null cases.
-- Additionally, it restores the cursor position as a side-effect.
-- @param mtype motion type
core.send_motion = function(mtype)
  core.send(nil, core.get_motion_selection(mtype))
  marks.winrestview()
end

--- Sends a chunk of text from a visual selection to the repl
-- this is a simple wrapper over @{core.get_visual_selection} where
-- the data is forwarded to the repl through @{core.send},
-- which will handle the null cases.
core.visual_send = function()
  core.send(nil, core.get_visual_selection())
end

--- Re-sends latest chunk of text.
-- Sends text contained within a block delimited by
-- the last sent chunk. Uses @{marks.get} to retrieve
-- the boundaries.
core.repeat_cmd = function()
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

  core.send(nil, lines)
end


--- List of commands created by iron.nvim
-- They'll only be set up after calling the @{core.setup} function
-- which makes it possible to delay initialization and make startup faster.
-- @local
-- @table commands
-- @field IronRepl command for @{core.repl_for}
local commands = {
  {"IronRepl", function(opts)
    local ft = opts.args[1] or ll.get_buffer_ft(0)
    core.repl_for(ft)
  end, {}},
  {"IronSend", function(opts)
    local ft
    if opts.bang then
      ft = opts.args[1]
      opts.args[1] = ""
    else
      ft = ll.get_buffer_ft(0)
    end
    if ft == nil then return end
    local data = table.join(vim.tbl_filter(function(x) return x == "" end, opts.args), " ")

    core.send(ft, data)
  end, {bang = true}},
  {"IronFocus", function(opts)
    local ft = opts.args[1] or ll.get_buffer_ft(0)
    if ft == nil then return end

    core.focus_on(ft)
  end, {}},
  {"IronReplHere", function(opts)
    local ft = opts.args[1] or ll.get_buffer_ft(0)
    if ft == nil then return end

    core.repl_here(ft)
  end, {}},
  {"IronRestart", function(_) core.repl_restart() end, {}}
}

--- Wrapper for calling functions through motion.
-- This should take care of the vim side of calling opfuncs.
-- @param motion_fn_name name of the function in @{core} to be mapped
core.run_motion = function(motion_fn_name)
  marks.winsaveview()
  vim.o.operatorfunc = 'v:lua.package.loaded.iron.core.' .. motion_fn_name
  vim.api.nvim_feedkeys("g@", "ni", false)
end


--- List of keymaps
-- if @{config}.should\_map\_plug is set to true,
-- then they will also be mapped to `<plug>` keymaps.
-- @table named_maps
-- @field send_motion mapping to send a motion/chunk to the repl
-- @field repeat_cmd repeats last executed motion
-- @field send_line sends current line to repl
-- @field visual_send sends visual selection to repl
-- @field clear_hl clears highlighted chunk
-- @field cr sends a <CR> to the repl
-- @field interrupt sends a <C-c> to the repl
-- @field exit closes the repl
-- @field clear clears the text buffer of the repl
local named_maps = {
  -- basic interaction with the repl
  send_motion = {{'n'}, function() require("iron.core").run_motion("send_motion") end},
  repeat_cmd = {{'n'}, core.repeat_cmd},
  send_line = {{'n'}, core.send_line},
  visual_send = {{'v'}, core.visual_send},

  -- Force clear highlight
  clear_hl = {{'v'}, marks.clear_hl},

  -- Sending special characters to the repl
  cr = {{'n'}, function() core.send(nil, string.char(13)) end},
  interrupt = {{'n'}, function() core.send(nil, string.char(03)) end},
  exit = {{'n'}, core.close_repl},
  clear = {{'n'}, function() core.send(nil, string.char(12)) end},
}


local snake_to_kebab = function(name)
  return name:gsub("_", "-")
end


--- Sets up the configuration for iron to run.
-- Also, defines commands and keybindings for iron to run.
-- @param opts table of the configuration to be applied
-- @tparam table opts.config set of config values to override default on @{config}
-- @tparam table opts.keymaps set of keymaps to apply, based on @{named_maps}
core.setup = function(opts)
  core.set_config(opts.config)

  if config.highlight_last ~= false then
    config.namespace = vim.api.nvim_create_namespace("iron")
    vim.api.nvim_set_hl(config.namespace, config.highlight_last, {
        bold = true
      })

    vim.api.nvim__set_hl_ns(config.namespace)
  end

  for _, command in ipairs(commands) do
     vim.api.nvim_create_user_command(unpack(command))
  end

  if config.should_map_plug then
    for key, keymap in ipairs(named_maps) do
      local mapping = vim.deepcopy(keymap)
      table.insert(mapping, 2, "<plug>(iron-" .. snake_to_kebab(key) .. ")")
      table.insert(mapping, {silent = true})
      vim.keymap.set(unpack(mapping))
    end
  end

  if opts.keymaps ~= nil then
    for key, lhs in pairs(opts.keymaps) do
      local mapping = vim.deepcopy(named_maps[key])
      table.insert(mapping, 2, lhs)
      table.insert(mapping, {silent = true})

      vim.keymap.set(unpack(mapping))
    end
  end
end

return core
