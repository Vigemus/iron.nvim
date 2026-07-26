local M = {}

local core = require("iron.core")
local state = require("iron.state")
local Repl = require("tests.integration.lib.repl")

function M.reset()
  for _, meta in pairs(state.repls or {}) do
    if meta.job then
      pcall(vim.fn.jobstop, meta.job)
    end

    if meta.bufnr and vim.api.nvim_buf_is_valid(meta.bufnr) then
      pcall(vim.api.nvim_buf_delete, meta.bufnr, { force = true })
    end
  end

  state.repls = {}
end

function M.create_repl(ft)
  return Repl.new(core.repl_for(ft))
end

function M.send(repl, text)
    core.send(repl:filetype(), text)
end

return M
