local ll = require("iron.lowlevel")

local Repl = {}
Repl.__index = Repl

function Repl.new(meta)
  return setmetatable({
    meta = meta,
  }, Repl)
end

function Repl:is_alive()
  return ll.repl_exists(self.meta)
end

function Repl:filetype()
  return self.meta.ft
end

function Repl:buffer()
  return self.meta.bufnr
end

function Repl:window()
  return vim.fn.bufwinid(self.meta.bufnr)
end

function Repl:id()
  return self.meta.job
end

function Repl:command()
  return self.meta.repldef.command
end

function Repl:contents()
  return vim.api.nvim_buf_get_lines(
    self:buffer(),
    0,
    -1,
    false
  )
end

function Repl:contains(text)
  for _, line in ipairs(self:contents()) do
    if line:find(text, 1, true) then
      return true
    end
  end

  return false
end

function Repl:wait_for(text, timeout_ms)
  timeout_ms = timeout_ms or 1000

  local ok = vim.wait(timeout_ms, function()
    return self:contains(text)
  end)

  assert.is_true(
    ok,
    ("Timed out waiting for %q"):format(text)
  )
end

return Repl
