-- luacheck: globals vim unpack
local fts = require("iron.fts")
local ll = require("iron.lowlevel")
local focus = require("iron.visibility").focus
local config = require("iron.config")
local marks = require("iron.marks")
local tables = require("iron.util.tables")

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
-- @return saved snapshot of repl metadata
new_repl.create = function(ft)
    local repl = ll.get_repl_def(ft)
    local meta = ll.create_repl_on_current_window(repl)
    ll.set(ft, meta)

    return meta
end

--- Create a new repl on a new repl window
-- Adds a layer on top of @{new_repl.create},
-- ensuring it is created on a new window
-- @param ft filetype
-- @return saved snapshot of repl metadata
new_repl.create_on_new_window = function(ft)
      local replwin = ll.new_window()

      vim.api.nvim_set_current_win(replwin)
      local meta = new_repl.create(ft)

      return meta
end

--- Creates a repl in the current window
-- @param ft the filetype of the repl to be created
core.repl_here = function(ft)
  return ll.if_repl_exists(ft, function(mem)
    vim.api.nvim_set_current_buf(mem.bufnr)
    return mem
  end, new_repl.create)
end

--- Restarts the repl for the current buffer
-- First, check if the cursor is on top or a REPL
-- Then, start a new REPL of the same type and enter it into the window
-- Afterwards, wipe out the old REPL buffer
-- This is done without asking for confirmation, so user beware
-- @todo Split into "restart a repl" and "do X for current buffer's repl"
core.repl_restart = function()
  local bufnr_here = vim.fn.bufnr("%")
  local ft = ll.get_repl_ft_for_bufnr(bufnr_here)

  if ft ~= nil then
    new_repl.create(ft)

    -- created a new one, now have to kill the old one
    vim.api.nvim_buf_delete(bufnr_here, {force = true})
    return meta
  else
    ft = vim.bo[bufnr_here].filetype

    return ll.if_repl_exists(ft, function(mem)
      local replwin = vim.fn.bufwinid(mem.bufnr)
      local currwin = vim.api.nvim_get_current_win()
      local meta

      if replwin == nil or replwin == -1 then
        meta = new_repl.create_on_new_window(ft)
      else
        vim.api.nvim_set_current_win(replwin)
        meta = new_repl.create(ft)
      end

      vim.api.nvim_set_current_win(currwin)
      vim.api.nvim_buf_delete(mem.bufnr, {force = true})

      return meta
      end, function()
      -- no repl found, so nothing to do
      vim.api.nvim_err_writeln('No repl found in current buffer; cannot restart')
    end)
  end
end

--- Sends a close request to the repl
-- if @{config.values.close_window_on_exit} is set to true,
-- all windows associated with that repl will be closed.
-- Otherwise, this will only finish the process.
-- @param ft filetype
core.close_repl = function(ft)
  ft = ft or ll.get_buffer_ft(0)
  if ft == nil then return end

  ll.send_to_repl(ft, string.char(04))
end

--- [Deprecated] sets up a repl by its name
-- The concept of named repls is confusing and while it makes
-- sense for storing them (or maybe not) the most important
-- thing is a direct configuration for the user, so this function
-- should be avoided
-- @param repl_name name of the configured repl
-- @param ft filetype
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

--- Creates a repl for a given filetype
-- It should open a new repl on a new window for the filetype
-- supplied as argument.
-- @param ft filetype
core.repl_for = function(ft)
  return ll.if_repl_exists(ft, function(mem)
    config.visibility(mem.bufnr, function()
           local winid = ll.new_window()
           vim.api.nvim_win_set_buf(winid, mem.bufnr)
           return winid
        end)
        return mem
    end, function(ft)
      local currwin = vim.api.nvim_get_current_win()
      local meta = new_repl.create_on_new_window(ft)
      vim.api.nvim_set_current_win(currwin)
      return meta
    end)
end

--- Moves to the repl for given filetype
-- When it doesn't exist, a new repl is created
-- directly moving the focus to it.
-- @param ft filetype
core.focus_on = function(ft)
  return ll.if_repl_exists(ft, function(mem)
    focus(mem.bufnr, function()
           local winid = ll.new_window()
           vim.api.nvim_win_set_buf(winid, mem.bufnr)
           return winid
        end)
        return mem
    end, new_repl.create_on_new_window)
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
  if ft == nil then return end
  -- If the repl doesn't exist, it will be created
  ll.if_repl_exists(ft, nil, core.repl_for)
  ll.send_to_repl(ft, data)
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

--- Sends a chunk of text to the repl
-- This is the lua counterpart of a opfunc, extended
-- to be used by visual as well.
-- It extracts data from marks and uses @{core.send} to
-- deliver the lines to the repl.
-- It marks the block sent to the repl, so resending the same chunk can be done
-- by @{core.repeat_cmd}. The block can be highlighted if
-- @{config.values.highlight_last} is not set to false.
-- Don't use this function directly, but rather either @{core.send_motion}
-- or @{core.visual_send}.
-- @param mode either "visual" or "motion"
-- @param mtype mode type, as supplied by map-operator.
core.send_chunk = function(mode, mtype)
  local bstart, bend

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

  core.send(nil, lines)
end

--- Sends data to a repl through a opfunc
-- Shouldn't be directly supplied but instead called through a wrapper.
core.send_motion = function(mtype) core.send_chunk("motion", mtype) end

--- Sends visually selected data to a repl
core.visual_send = function() core.send_chunk("visual") end

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
    if ft == nil then return end
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
  {"IronRestart", function(opts) core.repl_restart() end, {}}
}

--- Wrapper for calling functions through motion.
-- This should take care of the vim side of calling opfuncs.
-- @param motion_fn_name name of the function in @{core} to be mapped
core.set_motion = function(motion_fn_name)
  marks.winsaveview()
  vim.o.operatorfunc = 'v:lua.package.loaded.iron.core.' .. motion_fn_name
  marks.winrestview()
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
  send_motion = {{'n', 'v'}, '<Cmd>lua require("iron.core").set_motion("send_motion")<CR>g@' },
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
     vim.api.nvim_add_user_command(unpack(command))
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
