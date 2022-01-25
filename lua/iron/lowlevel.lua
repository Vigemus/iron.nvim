-- luacheck: globals vim
--- Low level functions for iron
-- This is needed to reduce the complexity of the user API functions.
-- There are a few rules to the functions in this document:
-- * They should not interact with each other
--    * An exception for this is @{//ll.get_repl_def} during the transition to v3
--    * The other exception is @{//ll.if_repl_exists}, which hides the complexity
--      of managing the session of a repl.
-- * They should do one small thing only
-- * They should not care about setting/cleaning up state (i.e. moving back to another window)
-- * They must be explicit in their documentation about the state changes they cause.
local config = require("iron.config")
local fts = require("iron.fts")
local format = require("iron.fts.common").functions.format
local view = require("iron.view")

local ll = {}

ll.store = {}

ll.get = function(ft)
  return config.scope.get(ll.store, ft)
end

ll.set = function(ft, fn)
  return config.scope.set(ll.store, ft, fn)
end

ll.get_buffer_ft = function(bufnr)
  local ft = vim.bo[bufnr].filetype
  if fts[ft] == nil then
    vim.api.nvim_err_writeln("There's no REPL definition for current filetype "..ft)
  else
    return ft
  end
end

--- Creates the repl in the current window
-- This function effectively creates the repl without caring
-- about window management. It is expected that the client
-- ensures the right window is created and active before calling this function.
-- @param repl definition of the repl being created
-- @param repl.command table with the command to be invoked.
-- @return unsaved metadata about created repl
ll.create_repl_on_current_window = function(repl)
  local bufnr = vim.api.nvim_create_buf(not config.scratch_repl, config.scratch_repl)
  vim.api.nvim_win_set_buf(0, bufnr)
  local job_id = vim.fn.termopen(repl.command)

  return {
    bufnr = bufnr,
    job = job_id,
    repldef = repl
  }
end

--- Wrapper function for getting repl definition from config
-- This allows for an easier transition between old and new methods
-- @param ft filetype of the desired repl
-- @return repl definition
ll.get_repl_def = function(ft)
  local repl = config.repl_definition[ft]
  if repl == nil then
    -- TODO Remove after deprecated fns are cleaned
    return ll.get_preferred_repl(ft)
  end
  return repl
end

--- Creates a new window for placing a repl.
-- Expected to be called before creating the repl.
-- It knows nothing about the repl and only takes in account the
-- configuration.
-- @warning changes the current window
-- @return window id of the newly created window
ll.new_window = function()
  local bufnr = vim.api.nvim_create_buf(not config.scratch_repl, config.scratch_repl)
  if type(config.repl_open_cmd) == "function" then
    return config.repl_open_cmd(buff)
  else
    return view.openwin(config.repl_open_cmd, bufnr)
  end
end

--- Conditional execution depending on repl existence
-- This fn wraps the logic of doing something if a repl exists or not.
-- Since this pattern repeats frequently, this is a way of wrapping the complexity
-- and skipping the need to "ensure a repl exists", for example.
-- @tparam ft string filetype for the repl to be checked
-- @tparam when_true_action function(mem) action to perform when a repl exists
-- @tparam when_false_action function(ft) action to perform when a repl does not exist
-- @return result of the called function (either when_true_action or when_false_action)
-- @treturn boolean whether the repl existed or not when the function was called
ll.if_repl_exists = function(ft, when_true_action, when_false_action)
  if ft == nil or ft == "" then
    vim.api.nvim_err_writeln("iron: Empty filetype. Aborting")
    return
    end

  local mem = ll.get(ft)

  if (mem ~= nil and vim.api.nvim_buf_is_loaded(mem.bufnr)) then
    -- Split from the if above so a nil true-action doesn't trigger a false-action.
    if when_true_action ~= nil then
      return when_true_action(mem), true
    end
  elseif when_false_action ~= nil then
    return when_false_action(ft), false
  end
end

--- Sends data to an existing repl of given filetype
-- The content supplied is ensured to be a table of lines,
-- being coerced if supplied as a string.
-- As a side-effect of pasting the contents to the repl,
-- it changes the scroll position of that window.
-- Does not affect currently active window and its cursor position.
-- @param ft name of the filetype
-- @param data A multiline string or a table containing lines to be sent to the repl
ll.send_to_repl = function(ft, data)
  local dt = data
  local mem = ll.get(ft)

  if type(data) == "string" then
    dt = vim.split(data, '\n')
  end

  dt = format(mem.repldef, dt)

  local window = vim.fn.bufwinid(mem.bufnr)
  vim.api.nvim_win_set_cursor(window, {vim.api.nvim_buf_line_count(mem.bufnr), 0})

  vim.api.nvim_call_function('chansend', {mem.job, dt})
  vim.api.nvim_win_set_cursor(window, {vim.api.nvim_buf_line_count(mem.bufnr), 0})
end

--- Tries to look up the corresponding filetype of a REPL
-- If the corresponding buffer number is a repl,
-- return its filetype otherwise return nil
-- @param bufnr number of the buffer being checked
-- @treturn string filetype of the buffer's repl (or nil if it doesn't have a repl associated)
ll.get_repl_ft_for_bufnr = function(bufnr)
  local ft_found
  for ft in pairs(ll.store) do
    local mem = ll.get(ft)
    if mem ~= nil and bufnr == mem.bufnr then
      ft_found = ft
      break
    end
  end
  return ft_found
end

-- [[ Below this line are deprecated functions to be removed ]] --

-- Deprecated
-- Usages migrated
ll.get_preferred_repl = function(ft)
  local repl_definitions = fts[ft]
  local preference = config.preferred[ft]
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

-- Deprecated
ll.new_repl_window = function(buff, ft)
  if type(config.repl_open_cmd) == "function" then
    return config.repl_open_cmd(buff, ft)
  else
    return view.openwin(config.repl_open_cmd, buff)
  end
end


-- Deprecated
ll.create_new_repl = function(ft, repl, new_win)
  -- make creation of new windows optional
  if new_win == nil then
    new_win = true
  end

  local winid
  local prevwin = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_create_buf(config.buflisted, true)

  if new_win then
    winid = ll.new_repl_window(bufnr, ft)
  else
    if ll.get(ft) == nil then
      winid = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(winid, bufnr)
    else
      winid = ll.get(ft).winid
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

  return ll.set(ft, inst)
end

-- Deprecated
ll.create_preferred_repl = function(ft, new_win)
    local repl = ll.get_repl_def(ft)

    if repl ~= nil then
      return ll.create_new_repl(ft, repl, new_win)
    end

    return nil
end

-- Deprecated
ll.ensure_repl_exists = function(ft)
  local mem = ll.get(ft)
  local created = false

  if mem == nil or vim.fn.bufname(mem.bufnr) == "" then
    mem = ll.create_preferred_repl(ft)
    created = true
  end

  return mem, created
end


return ll
