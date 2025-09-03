local M = {}

local is_dap_integration_enabled = false

--- Sets up a hook to keep track of the DAP session state.
function M.enable_integration()
  is_dap_integration_enabled = true
end

--- Returns true if dap_integration is enabled and a dap session is running.
--- This function will always return false if dap_integration is not enabled.
--- @return boolean
function M.is_dap_session_running()
  local has_dap, dap = pcall(require, 'dap')
  return has_dap and is_dap_integration_enabled and dap.session() ~= nil
end

--- Send the lines to the dap-repl
--- @param lines string|string[]
function M.send_to_dap(lines)
  local text
  if type(lines) == 'table' then
    text = table.concat(lines, "\n"):gsub('\r', '')
  else
    text = lines
  end
  require('dap').repl.execute(text)
  require('dap').repl.open()
end

return M
