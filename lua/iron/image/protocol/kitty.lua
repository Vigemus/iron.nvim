-- luacheck: globals vim
--- Kitty graphics protocol, spoken by kitty and ghostty.
-- Images are uploaded straight to the host terminal and placed with
-- Unicode placeholders, which the REPL prints as regular terminal text.

---@class iron.image.KittyProtocol : iron.image.Protocol
local kitty = {}

local esc = string.char(27)
local chunk_size = 4096

---@return boolean
local in_tmux = function()
  return (vim.env.TMUX or "") ~= ""
    or (vim.env.TERM or ""):match("^tmux") ~= nil
end

--- Writes one graphics command to the host terminal
---@param body string control data and payload, without the APC framing
local write = function(body)
  local sequence = esc .. "_G" .. body .. esc .. "\\"
  if in_tmux() then
    local escaped = sequence:gsub(esc, esc .. esc)
    sequence = esc .. "Ptmux;" .. escaped .. esc .. "\\"
  end
  if vim.api.nvim_ui_send then
    vim.api.nvim_ui_send(sequence)
  else
    vim.api.nvim_chan_send(vim.v.stderr, sequence)
  end
end

--- Whether the host terminal looks like it speaks the protocol
---@return boolean
kitty.detect = function()
  local term = vim.env.TERM or ""
  return term == "xterm-kitty"
    or term == "xterm-ghostty"
    or vim.env.TERM_PROGRAM == "ghostty"
    or (vim.env.KITTY_WINDOW_ID or "") ~= ""
    or (vim.env.GHOSTTY_RESOURCES_DIR or "") ~= ""
end

--- Reason the protocol can't be used right now, if any
---@return string?
kitty.check = function()
  if not vim.o.termguicolors then
    -- Placeholders carry the image id in their 24-bit foreground color
    return "termguicolors is required"
  end
end

--- Uploads a PNG and creates its virtual placement
---@param id integer image id
---@param png string PNG bytes
---@param rows integer height in cells
---@param cols integer width in cells
kitty.render = function(id, png, rows, cols)
  local data = vim.base64.encode(png)
  for offset = 1, #data, chunk_size do
    local header = offset == 1 and ("a=t,f=100,t=d,i=%d,q=2,"):format(id) or ""
    local more = offset + chunk_size <= #data and 1 or 0
    local chunk = data:sub(offset, offset + chunk_size - 1)
    write(header .. ("m=%d;%s"):format(more, chunk))
  end
  write(("a=p,U=1,i=%d,c=%d,r=%d,C=1,q=2"):format(id, cols, rows))
end

--- Frees an image in the host terminal
---@param id integer image id
kitty.delete = function(id)
  write(("a=d,d=I,i=%d,q=2"):format(id))
end

return kitty
