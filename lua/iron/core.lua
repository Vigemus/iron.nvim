-- luacheck: globals vim unpack

local log = require("iron.log")
local ll = require("iron.lowlevel")
local focus = require("iron.visibility").focus
local config = require("iron.config")
local marks = require("iron.marks")
local is_windows = require("iron.util.os").is_windows
local view = require("iron.view")

local autocmds = {}

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
-- @param bufnr buffer to be used.
-- @param current_bufnr current buffer.
-- @tparam cleanup function Function to cleanup if call fails
-- @return saved snapshot of repl metadata
new_repl.create = function(ft, bufnr, current_bufnr, cleanup)
  local meta
  local success, repl = pcall(ll.get_repl_def, ft)

  if not success and cleanup ~= nil then
    cleanup()
    error(repl)
  end

  success, meta = pcall(
    ll.create_repl_on_current_window,
    ft, repl, bufnr, current_bufnr
  )
  if success then
    ll.set(ft, meta)

    local filetype = config.repl_filetype(bufnr, ft)
    if filetype ~= nil then
      vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    end

    return meta
  elseif cleanup ~= nil then
    cleanup()
  end


  error(meta)
end

--- Create a new repl on a new repl window
-- Adds a layer on top of @{new_repl.create},
-- ensuring it is created on a new window
-- @param ft filetype
-- @return saved snapshot of repl metadata
new_repl.create_on_new_window = function(ft)
  local current_bufnr = vim.api.nvim_get_current_buf()
  local bufnr = ll.new_buffer()

  local replwin = ll.new_window(bufnr)
  vim.api.nvim_set_current_win(replwin)
  local meta = new_repl.create(ft, bufnr, current_bufnr, function()
    vim.api.nvim_win_close(replwin, true)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

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
    local current_bufnr = vim.api.nvim_get_current_buf()
    local bufnr = ll.new_buffer()
    return new_repl.create(ft, bufnr, current_bufnr, function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
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
  local current_bufnr = vim.api.nvim_get_current_buf()

  if ft ~= nil then
    local bufnr = ll.new_buffer()

    local meta = new_repl.create(
      ft, bufnr, current_bufnr,
      function()
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    )

    -- created a new one, now have to kill the old one
    vim.api.nvim_buf_delete(bufnr_here, { force = true })
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
        local bufnr = ll.new_buffer()
        new_meta = new_repl.create(
          ft, bufnr, current_bufnr,
          function()
          vim.api.nvim_buf_delete(bufnr, {force = true})
          end
        )
      end

      vim.api.nvim_set_current_win(currwin)
      vim.api.nvim_buf_delete(meta.bufnr, { force = true })

      return new_meta
    else
      error('No repl found in current buffer; cannot restart')
    end
  end
end

--- Sends a close request to the repl
-- if @{config.values.close_window_on_exit} is set to true,
-- all windows associated with that repl will be closed.
-- Otherwise, this will only finish the process.
-- @param ft filetype
core.close_repl = function(ft)
  -- see the similar logic on core.send to see how the REPLs created by
  -- core.attach is handled.
  local meta = vim.b[0].repl

  if not meta or not ll.repl_exists(meta) then
    ft = ft or ll.get_buffer_ft(0)
    meta = ll.get(ft)
  end

  if not ll.repl_exists(meta) then
    return
  end

  ll.send_to_repl(meta, string.char(04))
end

--- Hides the repl windows for a given filetype
-- @param ft filetype
core.hide_repl = function(ft)
  ft = ft or ll.get_buffer_ft(0)
  local meta = ll.get(ft)

  if ll.repl_exists(meta) then
    local window = vim.fn.bufwinid(meta.bufnr)
    if window ~= -1 then
      vim.api.nvim_win_hide(window)
    end
  end
end

--- Creates a repl for a given filetype
-- It should open a new repl on a new window for the filetype
-- supplied as argument.
-- @param ft filetype
core.repl_for = function(ft)
  local meta = ll.get(ft)
  if ll.repl_exists(meta) then
    local currwin = vim.api.nvim_get_current_win()
    config.visibility(meta.bufnr, function()
      local winid = ll.new_window(meta.bufnr)
      vim.api.nvim_win_set_buf(winid, meta.bufnr)
      vim.api.nvim_set_current_win(currwin)
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

--- Sends data to the repl
-- This is a top-level wrapper over the low-level
-- functions. It should send data to the repl, ensuring
-- it exists.
-- @param ft filetype (will be inferred if not supplied)
-- @tparam string|table data data to be sent to the repl.
local send = function(ft, data)
  -- the buffer local variable `repl` is created by core.attach function to
  -- track non-default REPls.
  local meta = vim.b[0].repl

  -- However, this attached meta may associated with a REPL that has been
  -- closed, we need to check for that.
  -- If the attached REPL is not existed or has been closed, we will try to
  -- get the REPL meta based on the ft of current buffer.
  if not meta or not ll.repl_exists(meta) then
    ft = ft or ll.get_buffer_ft(0)
    if data == nil then return end
    meta = ll.get(ft)
  end

  -- If the repl doesn't exist, it will be created
  if not ll.repl_exists(meta) then
    meta = core.repl_for(ft)
  end
  ll.send_to_repl(meta, data)
end


-- TODO fix this hack fix that allows ipython with Windows OS
-- To fix this, there needs to be some sort of check on the progress of the
-- call to vim.fn.chansend(meta.job, dt) inside of ll.send_to_repl. The defer
-- is here to ensure that sending of string.char(13) sends after the commands
-- are finished sending to the ipython REPL
core.send = function(ft, data)
  if not is_windows() then
    send(ft, data)
  else
    send(ft, data)

    -- This is a hack fix that allows windows ipython to run the commands sent
    -- to the repl. However, the same issue will arise as before (the command sent
    -- to the repl but the code not running) if many lines are sent to the ipython
    -- repl (many as in more than 150 milliseconds worth). It appear that windows
    -- and powershell works fine though.
    vim.defer_fn(function()
      send(nil, string.char(13))
      if type(data) ~= "string" then
        send(nil, string.char(13))
      end
    end, 150)
  end
end

core.send_file = function(ft)
  core.send(ft, vim.api.nvim_buf_get_lines(0, 0, -1, false))
end

--- Sends the line under the cursor to the repl
-- Builds upon @{core.send}, extracting
-- the data beforehand.
core.send_line = function()
  local linenr = vim.api.nvim_win_get_cursor(0)[1] - 1
  local cur_line = vim.api.nvim_buf_get_lines(0, linenr, linenr + 1, 0)[1]
  local width = vim.fn.strwidth(cur_line)

  if width == 0 then return end

  marks.set {
    from_line = linenr,
    from_col = 0,
    to_line = linenr,
    to_col = width - 1
  }

  core.send(nil, cur_line)
end

--- Sends the buffer from the beginning until reching the line where the cursror is (inclusive)
-- Builds upon @{core.send}, extracting
-- the data beforehand.
core.send_until_cursor = function()
  local linenr = vim.api.nvim_win_get_cursor(0)[1] - 1
  local text_until_line = vim.api.nvim_buf_get_lines(0, 0, linenr + 1, 0)
  local last_line = vim.api.nvim_buf_get_lines(0, linenr, linenr + 1, 0)[1]
  local last_line_width = vim.fn.strwidth(last_line)

  marks.set {
    from_line = 0,
    from_col = 0,
    to_line = linenr,
    to_col = last_line_width - 1
  }

  core.send(nil, text_until_line)
end

--- Marks visual selection and returns data for usage
-- @treturn table Marked lines
core.mark_visual = function()
  -- HACK Break out of visual mode
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', false, true, true), 'nx', false)
  local b_line, b_col
  local e_line, e_col

  local mode = vim.fn.visualmode()

  b_line, b_col = unpack(vim.fn.getpos("'<"), 2, 3)
  e_line, e_col = unpack(vim.fn.getpos("'>"), 2, 3)

  if e_line < b_line or (e_line == b_line and e_col < b_col) then
    e_line, b_line = b_line, e_line
    e_col, b_col = b_col, e_col
  end

  local lines = vim.api.nvim_buf_get_lines(0, b_line - 1, e_line, 0)

  if #lines == 0 then return end

  if mode == "\22" then
    local b_offset = math.max(1, b_col) - 1
    for ix, line in ipairs(lines) do
      -- On a block, remove all preciding chars unless b_col is 0/negative
      lines[ix] = vim.fn.strcharpart(line, b_offset, math.min(e_col, vim.fn.strwidth(line)))
    end
  elseif mode == "v" then
    local last = #lines
    local line_size = vim.fn.strwidth(lines[last])
    local max_width = math.min(e_col, line_size)
    if (max_width < line_size) then
      -- If the selected width is smaller then total line, trim the excess
      lines[last] = vim.fn.strcharpart(lines[last], 0, max_width)
    end

    if b_col > 1 then
      -- on a normal visual selection, if the start column is not 1, trim the beginning part
      lines[1] = vim.fn.strcharpart(lines[1], b_col - 1)
    end
  end

  marks.set {
    from_line = b_line - 1,
    from_col = math.max(b_col - 1, 0),
    to_line = e_line - 1,
    to_col = math.min(e_col, vim.fn.strwidth(lines[#lines])) - 1 -- TODO Check whether this is actually true
  }

  if config.ignore_blank_lines then
    local b_lines = {}
    for _, line in ipairs(lines) do
      if line:gsub("^%s*(.-)%s*$", "%1") ~= '' then
        table.insert(b_lines, line)
      end
    end
    return b_lines
  else
    return lines
  end
end

--- Marks the supplied motion and returns the data for usage
-- @tparam string mtype motion type
-- @treturn table Marked lines
core.mark_motion = function(mtype)
  local b_line, b_col
  local e_line, e_col

  b_line, b_col = unpack(vim.fn.getpos("'["), 2, 3)
  e_line, e_col = unpack(vim.fn.getpos("']"), 2, 3)

  local lines = vim.api.nvim_buf_get_lines(0, b_line - 1, e_line, 0)
  if #lines == 0 then return end

  if mtype == 'line' then
    b_col, e_col = 0, vim.fn.strwidth(lines[#lines])
  end

  if e_col > 1 then
    lines[#lines] = vim.fn.strpart(lines[#lines], 0, e_col)
  end
  if b_col > 1 then
    lines[1] = vim.fn.strpart(lines[1], b_col - 1)
  end

  marks.set {
    from_line = b_line - 1,
    from_col = math.max(b_col - 1, 0),
    to_line = e_line - 1,
    to_col = e_col - 1
  }

  marks.winrestview()
  return lines
end

--- Sends a chunk of text from a motion to the repl
-- It is a simple wrapper over @{core.mark_motion}
-- in which the data is extracted by that function and sent to the repl.
-- @{core.send} will handle the null cases.
-- Additionally, it restores the cursor position as a side-effect.
-- @param mtype motion type
core.send_motion = function(mtype)
  core.send(nil, core.mark_motion(mtype))
end

--- Sends a chunk of text from a visual selection to the repl
-- this is a simple wrapper over @{core.mark_visual} where
-- the data is forwarded to the repl through @{core.send},
-- which will handle the null cases.
core.visual_send = function()
  core.send(nil, core.mark_visual())
end

--- Sends the paragraph to the REPL that the cursor is on
core.send_paragraph = function()
  vim.cmd('normal! vip')
  vim.defer_fn(function()
    core.visual_send()
  end, 100)
end


--- Re-sends latest chunk of text.
-- Sends text contained within a block delimited by
-- the last sent chunk. Uses @{marks.get} to retrieve
-- the boundaries.
core.send_mark = function()
  local pos = marks.get()

  if pos == nil then return end

  local lines = vim.api.nvim_buf_get_lines(0, pos.from_line, pos.to_line + 1, 0)

  if #lines == 1 then
    if pos.from_col >= 1 or pos.to_col < vim.fn.strwidth(lines[1]) - 1 then
      lines[1] = vim.fn.strpart(lines[1], pos.from_col, pos.to_col - pos.from_col + 1)
    end
  else
    if pos.from_col >= 1 then
      lines[1] = vim.fn.strpart(lines[1], pos.from_col)
    end
    if pos.to_col < vim.fn.strwidth(lines[#lines]) - 1 then
      lines[#lines] = vim.fn.strpart(lines[#lines], 0, pos.to_col + 1)
    end
  end

  core.send(nil, lines)
end

--- Checks if line starts with a devider.
-- Helper function for core.send_code_block.
local line_starts_with_block_devider = function(line, block_deviders)
  for _, block_devider in pairs(block_deviders) do
    local length_block_devider = string.len(block_devider)
    if string.sub(line, 1, length_block_devider) == block_devider then return true end
  end
end

--- Sends lines between two block deviders.
-- Block deviders can be defined as table in the
-- repl_definition under key block_deviders.
-- The buffer is scanned from cursor till first line
-- starting with a block_devider or the start of buffer.
-- The buffer is scanned till end of buffer for next line
-- starting with a block devider or end of buffer.
-- If no block_devider is defined an error is returned.
-- If move is true, the cursor is moved to the next block_devider
-- for jumping through the code. If move is false, the cursor is
-- not moved.
core.send_code_block = function(move)
  local block_deviders = config.repl_definition[vim.bo[0].filetype].block_deviders
  if block_deviders == nil then
    error("No block_deviders defined for this repl in repl_definition!")
  end
  local linenr = vim.api.nvim_win_get_cursor(0)[1] - 1
  local buffer_text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local mark_start = linenr
  while mark_start ~= 0 do
    local line_text = buffer_text[mark_start + 1]
    if line_starts_with_block_devider(line_text, block_deviders) then break end
    mark_start = mark_start - 1
  end
  local buffer_length = vim.api.nvim_buf_line_count(0)
  local mark_end = linenr + 1
  while mark_end < buffer_length do
    local line_text = buffer_text[mark_end + 1]
    if line_starts_with_block_devider(line_text, block_deviders) then break end
    mark_end = mark_end + 1
  end
  mark_end = mark_end - 1
  local col_end = string.len(buffer_text[mark_end + 1]) - 1
  marks.set {
    from_line = mark_start,
    from_col = 0,
    to_line = mark_end,
    to_col = col_end,
  }
  core.send_mark()
  if move then vim.api.nvim_win_set_cursor(0, { math.min(mark_end + 2, buffer_length), 0 }) end
end

--- Attaches a buffer to a repl regardless of it's filetype
-- If the repl doesn't exist it will be created
core.attach = function(ft, target)
  local meta = ll.get(ft)

  if not ll.repl_exists(meta) then
    meta = core.repl_for(ft)
  end

  vim.b[target].repl = meta
end

--- Provide filtered list of supported fts
-- Auxiliary function to be used by commands to show the user which fts they have
-- available to start repls with
-- @param partial input string
-- @return table with supported filetypes matching input string
local complete_fts = function(partial)
  local starts_with_partial = function(key) return key:sub(1, #partial) == partial end
  local custom_fts = vim.tbl_filter(starts_with_partial, vim.tbl_keys(config.repl_definition))
  vim.list_extend(custom_fts, vim.tbl_filter(
    function(i) return (not vim.tbl_contains(custom_fts, i)) and starts_with_partial(i) end,
    vim.tbl_keys(require("iron.fts")))
  )

  return custom_fts
end

local get_ft = function(arg)
  if arg and arg ~= "" then
    return arg
  end
  return ll.get_buffer_ft(0)
end

--- List of commands created by iron.nvim
-- They'll only be set up after calling the @{core.setup} function
-- which makes it possible to delay initialization and make startup faster.
-- @local
-- @table commands
-- @field IronRepl command for @{core.repl_for}
local commands = {
  { "IronAttach", function(opts)
    core.attach(get_ft(opts.fargs[1]), vim.api.nvim_get_current_buf())
  end, { nargs = "?", complete = complete_fts } },
  { "IronRepl", function(opts)
    core.repl_for(get_ft(opts.fargs[1]))
  end, { nargs = "?", complete = complete_fts } },
  { "IronHide", function(opts)
    core.hide_repl(get_ft(opts.fargs[1]))
  end, { nargs = "?", complete = complete_fts } },
  { "IronSend", function(opts)
    local ft
    if opts.bang then
      ft = opts.fargs[1]
      opts.fargs[1] = ""
    else
      ft = ll.get_buffer_ft(0)
    end
    if ft == nil then return end
    local data = table.concat(opts.fargs, " ")

    core.send(ft, data)
  end, {
    bang = true,
    nargs = "+",
    complete = function(arg_lead, cmd_line)
      local cmd = vim.split(cmd_line, " ")
      if #cmd <= 2 and string.find(cmd[1], "!") then
        return complete_fts(arg_lead)
      end
    end
  } },
  { "IronFocus", function(opts)
    local ft = get_ft(opts.fargs[1])
    if ft == nil then return end

    core.focus_on(ft)
  end, { nargs = "?", complete = complete_fts } },
  { "IronWatch", function(opts)
    local handler

    if opts.fargs[1] == "mark" then
      handler = core.send_mark
    elseif opts.fargs[1] == "file" then
      -- Wrap send_file so we ingore autocmd argument
      handler = function() core.send_file() end
    else
      error("Not a valid handler type")
    end

    core.watch(handler)
  end, {
    nargs = 1,
    complete = function(arg_lead, _)
      local starts_with_partial = function(key) return key:sub(1, #arg_lead) == arg_lead end
      return vim.tbl_filter(starts_with_partial, {
        "mark",
        "file"
      })
    end
  } },
  { "IronReplHere", function(opts)
    local ft = get_ft(opts.fargs[1])
    if ft == nil then return end

    core.repl_here(ft)
  end, { nargs = "?", complete = complete_fts } },
  { "IronRestart", function(_) core.repl_restart() end, { nargs = 0 } }
}

--- Wrapper for calling functions through motion.
-- This should take care of the vim side of calling opfuncs.
-- @param motion_fn_name name of the function in @{core} to be mapped
core.run_motion = function(motion_fn_name)
  marks.winsaveview()
  vim.o.operatorfunc = "v:lua.require'iron.core'." .. motion_fn_name
  vim.api.nvim_feedkeys("g@", "ni", false)
end

core.unwatch = function(bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  if autocmds[fname] ~= nil then
    vim.api.nvim_del_autocmd(autocmds[fname])
    autocmds[fname] = nil
  end
end

core.watch = function(handler, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  core.unwatch(bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  autocmds[fname] = vim.api.nvim_create_autocmd("BufWritePost", {
    group = "iron",
    pattern = fname,
    callback = handler,
    desc = "Watch writes to buffer to send data to repl"
  })
end

--- List of keymaps
-- if @{config}.should\_map\_plug is set to true,
-- then they will also be mapped to `<plug>` keymaps.
-- @table named_maps
-- @field send_motion mapping to send a motion/chunk to the repl

-- @field send_mark Sends chunk within marked boundaries
-- @field send_line sends current line to repl
-- @field send_until_cursor sends the buffer from the start until the line where the cursor is (inclusive) to the repl
-- @field visual_send sends visual selection to repl
-- @field clear_hl clears highlighted chunk
-- @field cr sends a <CR> to the repl
-- @field interrupt sends a <C-c> to the repl
-- @field exit closes the repl
-- @field clear clears the text buffer of the repl
local named_maps = {
  -- basic interaction with the repl
  send_motion = {
    { 'n' },
    function() require("iron.core").run_motion("send_motion") end
  },
  send_mark = { { 'n' }, core.send_mark },
  send_line = { { 'n' }, core.send_line },
  send_until_cursor = { { 'n' }, core.send_until_cursor },
  send_file = { { 'n' }, core.send_file },
  visual_send = { { 'v' }, core.visual_send },
  send_paragraph = { { 'n' }, core.send_paragraph },
  send_code_block = { { 'n' }, function() core.send_code_block(false) end },
  send_code_block_and_move = {
    { 'n' }, function() core.send_code_block(true) end
  },

  -- REPL
  restart_repl = { { 'n' }, function() vim.cmd("IronRestart") end },
  toggle_repl = { { 'n' }, function() vim.cmd("IronRepl") end },

  -- Marks
  mark_motion = { { 'n' }, function() require("iron.core").run_motion("mark_motion") end },
  mark_visual = { { 'v' }, core.mark_visual },
  remove_mark = { { 'n' }, marks.drop_last },

  -- Force clear highlight
  clear_hl = { { 'v' }, marks.clear_hl },

  -- Sending special characters to the repl
  cr = { { 'n' }, function() core.send(nil, string.char(13)) end },
  interrupt = { { 'n' }, function() core.send(nil, string.char(03)) end },
  exit = { { 'n' }, core.close_repl },
  clear = { { 'n' }, function() core.send(nil, string.char(12)) end },
}

local tmp_migration = {
  repeat_cmd = "send_mark"
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
  config.namespace = vim.api.nvim_create_namespace("iron")
  vim.api.nvim_create_augroup("iron", {})

  if opts.config then
    if type(opts.config.repl_open_cmd) ~= "table" then
      ll.tmp.repl_open_cmd = opts.config.repl_open_cmd

    else
      for idx, cmd in ipairs(opts.config.repl_open_cmd) do
        if idx == 1 then
          ll.tmp.repl_open_cmd = cmd
        end
        named_maps["toggle_repl_with_cmd_" .. idx] = {
          { 'n' },
          function()
            ll.tmp.repl_open_cmd = cmd
            vim.cmd('IronRepl')
          end
        }
      end
    end

    if ll.tmp.repl_open_cmd == nil then
      local msg = "A default repl_open_cmd was not set. "
      msg = msg .. "Please set a default by adding '_DEFAULT' "
      msg = msg .. "to the end of one of your repl_open_cmd names."
      error(msg)
    end

    for k, v in pairs(opts.config) do
      config[k] = v
    end

  else
    ll.tmp.repl_open_cmd = config.repl_open_cmd
  end


  if config.highlight_last ~= false then
    local hl_cfg = opts.highlight or {
      bold = true
    }


    vim.api.nvim_set_hl(0, config.highlight_last, hl_cfg)
  end

  for _, command in ipairs(commands) do
    vim.api.nvim_create_user_command(unpack(command))
  end

  if config.should_map_plug then
    vim.deprecate("config.should_map_plug", "core.setup{keymaps = {...}}", "3.1", "iron.nvim")
    for key, keymap in pairs(named_maps) do
      local mapping = vim.deepcopy(keymap)
      table.insert(mapping, 2, "<plug>(iron-" .. snake_to_kebab(key) .. ")")
      table.insert(mapping, { silent = true })
      vim.keymap.set(unpack(mapping))
    end
  end

  if opts.keymaps ~= nil then
    for key, lhs in pairs(opts.keymaps) do
      if tmp_migration[key] ~= nil then
        log.deprecate(
          "core.setup{keymaps." .. key .. "}",
          "core.setup{keymaps." .. tmp_migration[key] .. "}",
          "3.1",
          "iron.nvim"
        )
        key = tmp_migration[key]
      end

      if named_maps[key] == nil then
        error("Key `" .. key .. "` doesn't exist, therefore there's nothing to be applied")
      else
        local mapping = vim.deepcopy(named_maps[key])
        table.insert(mapping, 2, lhs)
        table.insert(mapping, { silent = true, desc = 'iron_repl_' .. key })

        vim.keymap.set(unpack(mapping))
      end
    end
  end
end

return core
