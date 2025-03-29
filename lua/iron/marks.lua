-- luacheck: globals vim
local config = require("iron.config")

--- Marks management for iron
-- This is an intermediary layer between iron and neovim's
-- extmarks. Used primarily to manage the text sent to the repl,
-- but can also be used to set highlight and possibly virtualtext.
local marks = {}

--- Sets a mark for given options
-- The mark is set for a preconfigured position id, which will be used by
-- @{marks.get} for retrieval.
-- @tparam table opts table with the directives
-- @tparam number opts.from_line line where the mark starts
-- @tparam number opts.to_line line where the mark ends. Can be ignored on single line marks
-- @tparam number opts.from_col column where the mark starts
-- @tparam number opts.to_col column where the mark ends
-- @tparam string|false opts.hl Highlight group to be used or false if no highlight should be done.
marks.set = function(opts)
  local extmark_config = {
    id = config.mark.send,
    -- to_line can be ignored if it's single line
    end_line = opts.to_line or opts.from_line,
    end_col = opts.to_col + 1
  }

  if opts.hl ~= nil then

    -- Intentionally check here
    -- so opts.false disables highlight
    if opts.hl ~= false then
      extmark_config.hl_group = opts.hl
    end

  elseif config.highlight_last then
    extmark_config.hl_group = config.highlight_last
  end

  vim.api.nvim_buf_set_extmark(0, config.namespace, opts.from_line, opts.from_col, extmark_config)
end

marks.drop_last = function()
  vim.api.nvim_buf_del_extmark(0, config.namespace, config.mark.send)
end

marks.clear_hl = function()
  local payload = marks.get()
  payload.hl = false
  marks.set(payload)
end

--- Retrieves the mark with a position id.
marks.get = function()
  local mark_pos = vim.api.nvim_buf_get_extmark_by_id(0, config.namespace, config.mark.send, {details = true})

  if #mark_pos == 0 then
    return nil
  end

  return {
    from_line = mark_pos[1],
    from_col = mark_pos[2],
    to_line = mark_pos[3].end_row,
    to_col = mark_pos[3].end_col - 1
  }

end

marks.winrestview = function()
  local mark = vim.api.nvim_buf_get_extmark_by_id(0, config.namespace, config.mark.save_pos, {})

  if #mark ~= 0 then
    -- winrestview is 1-based
    vim.fn.winrestview({lnum = mark[1] + 1, col = mark[2]})
    vim.api.nvim_buf_del_extmark(0, config.namespace, config.mark.save_pos)
  end
end

marks.winsaveview = function()
  local pos = vim.fn.winsaveview()
  vim.api.nvim_buf_set_extmark(0, config.namespace, pos.lnum - 1, pos.col, {id = config.mark.save_pos})
end

return marks
