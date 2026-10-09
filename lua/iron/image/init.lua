-- luacheck: globals vim
--- Inline images for terminal REPLs.
-- A helper running inside the REPL emits each PNG as base64 chunks:
--   ESC ] 51;iron-image;<id>;<cols>;<rows>;<part>;<more>;<chunk> BEL
-- and then prints the cells the image covers. Neovim hands the chunks to
-- TermRequest; this module reassembles the PNG, keeps a copy on disk and
-- asks a protocol to draw it in the host terminal.
--
-- Languages live in image/lang/<ft>.lua, protocols in
-- image/protocol/<name>.lua; their interfaces are the classes below.

---@class iron.image.Lang
---@field prepare fun(cmd: string[], env: table<string, string>): string[], table<string, string>

---@class iron.image.Protocol
---@field detect fun(): boolean
---@field check fun(): string?
---@field render fun(id: integer, png: string, rows: integer, cols: integer)
---@field delete fun(id: integer)

---@class iron.image.Settings
---@field protocol? string
---@field max_images integer

---@class iron.image.Entry
---@field id integer
---@field path string
---@field row integer? first buffer line the image covers
---@field rows integer

---@class iron.image.Pending
---@field id integer
---@field cols integer
---@field rows integer
---@field row integer?
---@field chunks string[]

---@class iron.image.Session
---@field namespace integer
---@field protocol iron.image.Protocol
---@field max_images integer
---@field images iron.image.Entry[]
---@field last_id integer
---@field dir string
---@field pending iron.image.Pending?

local image = {}

local protocols = { "kitty" }
local prefix = string.char(27) .. "]51;iron-image;"
local pattern = "^"
  .. vim.pesc(prefix)
  .. "(%d+);(%d+);(%d+);(%d+);([01]);([%w+/=]+)$"
local chunk_size = 4096
local max_chunks = 4096 -- 12 MiB of PNG
local max_rows, max_cols = 20, 256

---@type table<integer, iron.image.Session>
local sessions = {}
local group = vim.api.nvim_create_augroup("IronImages", { clear = true })

---@param msg string
local warn = function(msg)
  vim.notify("iron: " .. msg, vim.log.levels.WARN)
end

--- Normalizes the `image` field of a repl definition
---@param value boolean|table|nil
---@return iron.image.Settings? settings nil when images are off
local settings_for = function(value)
  if value == nil or value == false then
    return nil
  elseif value == true then
    value = {}
  elseif type(value) ~= "table" then
    error("iron: image must be a boolean or a table")
  end

  local settings = vim.tbl_extend("force", { max_images = 100 }, value)
  local max = settings.max_images
  if type(max) ~= "number" or max < 1 or max % 1 ~= 0 then
    error("iron: image.max_images must be a positive integer")
  end
  return settings
end

--- Picks the configured protocol, or the first one detected
---@param name string?
---@return iron.image.Protocol? protocol
---@return string? reason why no protocol was picked
local pick_protocol = function(name)
  if name then
    local ok, protocol = pcall(require, "iron.image.protocol." .. name)
    if not ok then
      return nil, "unknown image protocol " .. name
    end
    return protocol
  end

  for _, candidate in ipairs(protocols) do
    local protocol = require("iron.image.protocol." .. candidate)
    if protocol.detect() then
      return protocol
    end
  end
  return nil, "no supported image protocol detected"
end

--- Image ids are namespace * 65536 + serial, so each repl gets its own range
---@return integer?
local free_namespace = function()
  local used = {}
  for _, session in pairs(sessions) do
    used[session.namespace] = true
  end
  for namespace = 128, 255 do
    if not used[namespace] then
      return namespace
    end
  end
end

---@param session iron.image.Session
---@param entry iron.image.Entry
local forget = function(session, entry)
  pcall(session.protocol.delete, entry.id)
  os.remove(entry.path)
end

--- Saves a PNG to the session dir and draws it
---@param session iron.image.Session
---@param pending iron.image.Pending
---@param png string
local store = function(session, pending, png)
  vim.fn.mkdir(session.dir, "p")
  local path = ("%s/%d.png"):format(session.dir, pending.id)
  local file = assert(io.open(path, "wb"))
  file:write(png)
  file:close()

  session.protocol.render(pending.id, png, pending.rows, pending.cols)
  table.insert(session.images, {
    id = pending.id,
    path = path,
    row = pending.row,
    rows = pending.rows,
  })
  if #session.images > session.max_images then
    forget(session, table.remove(session.images, 1))
  end
end

--- Handles one image chunk received from the repl
---@param session iron.image.Session
---@param sequence string
---@param cursor? integer[] (1,0)-indexed cursor when the chunk arrived
local receive = function(session, sequence, cursor)
  sequence = sequence:gsub("\7$", ""):gsub(string.char(27) .. "\\$", "")
  local id_s, cols_s, rows_s, part_s, more, chunk = sequence:match(pattern)
  if not id_s then
    return
  end
  local id = tonumber(id_s) --[[@as integer]]
  local cols = tonumber(cols_s) --[[@as integer]]
  local rows = tonumber(rows_s) --[[@as integer]]
  local part = tonumber(part_s) --[[@as integer]]

  local base = session.namespace * 65536
  if
    id <= base
    or id >= base + 65536
    or cols < 1
    or cols > max_cols
    or rows < 1
    or rows > max_rows
    or #chunk > chunk_size
    or #chunk % 4 ~= 0
    or (more == "1" and #chunk ~= chunk_size)
  then
    session.pending = nil
    return
  end

  if part == 0 then
    -- Ids are never reused, so old scrollback can't show a new image
    if id <= session.last_id then
      return
    end
    session.pending = {
      id = id,
      cols = cols,
      rows = rows,
      row = cursor and cursor[1] or nil,
      chunks = {},
    }
  end

  local pending = session.pending
  if
    not pending
    or pending.id ~= id
    or pending.cols ~= cols
    or pending.rows ~= rows
    or part ~= #pending.chunks
    or part >= max_chunks
  then
    session.pending = nil
    return
  end

  table.insert(pending.chunks, chunk)
  if more == "1" then
    return
  end
  session.pending = nil
  session.last_id = id

  local ok, png = pcall(vim.base64.decode, table.concat(pending.chunks))
  if
    not ok
    or png:sub(1, 8) ~= "\137PNG\r\n\26\n"
    or png:sub(13, 16) ~= "IHDR"
  then
    return
  end
  store(session, pending, png)
end

--- Stops tracking images for a repl buffer and frees them
---@param bufnr integer repl buffer
image.detach = function(bufnr)
  local session = sessions[bufnr]
  if not session then
    return
  end
  sessions[bufnr] = nil
  for _, entry in ipairs(session.images) do
    pcall(session.protocol.delete, entry.id)
  end
  vim.fn.delete(session.dir, "rf")
  vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })
end

--- Prepares a repl definition to render images in bufnr.
-- Must run before the terminal starts so no image output is missed.
-- When images can't be enabled it warns and returns repl unchanged.
---@param ft string filetype
---@param repl table repl definition
---@param bufnr integer buffer the repl will run in
---@param current_bufnr integer buffer the repl is created from
---@return table repl definition to start
image.attach = function(ft, repl, bufnr, current_bufnr)
  local settings = settings_for(repl.image)
  if settings == nil then
    return repl
  end

  local has_lang, lang = pcall(require, "iron.image.lang." .. ft)
  if not has_lang then
    warn("image support is not available for " .. ft)
    return repl
  end
  ---@cast lang iron.image.Lang

  local protocol, reason = pick_protocol(settings.protocol)
  if protocol then
    reason = protocol.check()
  end
  if not protocol or reason then
    warn("images disabled, " .. reason)
    return repl
  end

  local cmd = repl.command
  if type(cmd) == "function" then
    cmd = cmd({ current_bufnr = current_bufnr })
  end
  if type(cmd) ~= "table" then
    warn("images disabled, the repl command must be a list")
    return repl
  end

  image.detach(bufnr)
  local namespace = free_namespace()
  if not namespace then
    warn("images disabled, too many image repls")
    return repl
  end

  local env = vim.tbl_extend("force", {}, repl.env or {})
  local ok, prepared_cmd, prepared_env =
    pcall(lang.prepare, vim.list_extend({}, cmd), env)
  if not ok then
    warn("images disabled, " .. tostring(prepared_cmd))
    return repl
  end
  prepared_env.IRON_IMAGE_NAMESPACE = tostring(namespace)

  ---@type iron.image.Session
  local session = {
    namespace = namespace,
    protocol = protocol,
    max_images = settings.max_images,
    images = {},
    last_id = 0,
    dir = vim.fn.fnamemodify(vim.fn.tempname(), ":h")
      .. "/iron-images/"
      .. bufnr,
  }
  sessions[bufnr] = session

  vim.api.nvim_create_autocmd("TermRequest", {
    group = group,
    buffer = bufnr,
    callback = function(args)
      local data = args.data or {}
      if (data.sequence or ""):sub(1, #prefix) ~= prefix then
        return
      end
      local success, err = pcall(receive, session, data.sequence, data.cursor)
      if not success then
        warn("image rendering failed: " .. tostring(err))
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = bufnr,
    once = true,
    callback = function()
      image.detach(bufnr)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    once = true,
    callback = function()
      for buf in pairs(sessions) do
        image.detach(buf)
      end
    end,
  })

  return vim.tbl_extend(
    "force",
    repl,
    { command = prepared_cmd, env = prepared_env }
  )
end

--- Whether bufnr is a repl with images enabled
---@param bufnr integer
---@return boolean
image.enabled = function(bufnr)
  return sessions[bufnr] ~= nil
end

--- Finds the image covering a buffer line, or the latest one
---@param bufnr integer repl buffer
---@param row integer? 1-indexed buffer line
---@return string? path to the PNG
image.find = function(bufnr, row)
  local session = sessions[bufnr]
  if not session or #session.images == 0 then
    return nil
  end
  if row then
    for _, entry in ipairs(session.images) do
      if entry.row and row >= entry.row and row < entry.row + entry.rows then
        return entry.path
      end
    end
  end
  return session.images[#session.images].path
end

return image
