-- Inline PNG transport for terminal REPLs. Uploads bypass the embedded terminal;
-- Unicode placeholders travel through it and therefore follow its scrollback.
local M = {}
local sessions = {}
local esc = string.char(27)
local max_chunks = 4096 -- 16 MiB base64 (12 MiB PNG)
local group = vim.api.nvim_create_augroup("IronImages", { clear = false })

local function send(body)
  local sequence = esc .. "_G" .. body .. esc .. "\\"
  if (vim.env.TMUX and vim.env.TMUX ~= "") or (vim.env.TERM or ""):match("^tmux") then
    sequence = esc .. "Ptmux;" .. sequence:gsub(esc, esc .. esc) .. esc .. "\\"
  end
  if type(vim.api.nvim_ui_send) == "function" then
    vim.api.nvim_ui_send(sequence)
  else
    vim.api.nvim_chan_send(vim.v.stderr, sequence)
  end
end

local function delete(id)
  send(("a=d,d=I,i=%d,q=2"):format(id))
end

function M.detach(bufnr)
  local session = sessions[bufnr]
  if not session then return end
  sessions[bufnr] = nil
  for _, id in ipairs(session.images) do
    pcall(delete, id)
  end
  vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })
end

local function receive(session, sequence)
  -- TermRequest omits the OSC terminator. Accept it as well for direct callers.
  sequence = sequence:gsub("\7$", ""):gsub(esc .. "\\$", "")
  local id, cols, rows, part, more, chunk = sequence:match(
    "^" .. esc .. "%]51;iron%-image;(%d+);(%d+);(%d+);(%d+);([01]);([A-Za-z0-9+/=]+)$"
  )
  if not id then return end
  id, cols, rows, part, more = tonumber(id), tonumber(cols), tonumber(rows), tonumber(part), tonumber(more)
  local base = session.namespace * 65536
  if id <= base or id >= base + 65536 or cols < 1 or cols > 256 or rows < 1 or rows > 64
    or #chunk > 4096 or #chunk % 4 ~= 0 or (more == 1 and #chunk ~= 4096) then
    session.pending = nil
    return
  end
  if part == 0 then
    -- IDs are never reused: old scrollback must not start displaying a new PNG.
    if id <= session.last_id then return end
    session.pending = { id = id, cols = cols, rows = rows, chunks = {} }
  end
  local pending = session.pending
  if not pending or pending.id ~= id or pending.cols ~= cols or pending.rows ~= rows
    or part ~= #pending.chunks or part >= max_chunks then
    session.pending = nil
    return
  end
  pending.chunks[#pending.chunks + 1] = chunk
  if more == 1 then return end
  session.pending = nil
  local payload = table.concat(pending.chunks)
  local ok, png = pcall(vim.base64.decode, payload)
  if not ok or #png < 24 or png:sub(1, 8) ~= "\137PNG\r\n\26\n" or png:sub(13, 16) ~= "IHDR" then
    return
  end
  for index, data in ipairs(pending.chunks) do
    local header = index == 1 and ("a=t,f=100,t=d,i=%d,q=2,"):format(id) or ""
    send(header .. ("m=%d;%s"):format(index < #pending.chunks and 1 or 0, data))
  end
  send(("a=p,U=1,i=%d,c=%d,r=%d,C=1,q=2"):format(id, cols, rows))
  session.last_id = id
  session.images[#session.images + 1] = id
  if #session.images > session.max_images then
    delete(table.remove(session.images, 1))
  end
end

-- Called before termopen so no startup output can race the TermRequest handler.
function M.prepare(ft, command, opts, bufnr, settings)
  if ft ~= "python" then error("iron: image rendering currently supports Python REPLs") end
  if vim.fn.has("nvim-0.11") == 0 then error("iron: inline images require Neovim 0.11+") end
  if not vim.o.termguicolors then error("iron: inline images require termguicolors") end
  if type(command) ~= "table" or type(command[1]) ~= "string" then
    error("iron: image-enabled REPL command must be an argument list")
  end
  local name = vim.fn.fnamemodify(command[1], ":t"):lower():gsub("%.exe$", "")
  local ipython = name:match("^ipython[%d.]*$") ~= nil
  local python = name:match("^python[%d.]*$") ~= nil
  local jupyter = name == "jupyter-console" or (name == "jupyter" and command[2] == "console")
  if not ipython and not python and not jupyter then
    error("iron: image rendering requires a python, ipython, or jupyter-console executable")
  end
  local cmd = vim.list_extend({}, command)
  -- Leave interpreter flags in place for module-style launches.
  if python then
    for index = 2, #cmd do
      local arg = cmd[index]
      if arg == "-m" then
        ipython = cmd[index + 1] == "IPython"
        jupyter = cmd[index + 1] == "jupyter_console"
          or (cmd[index + 1] == "jupyter" and cmd[index + 2] == "console")
        break
      end
      if arg == "-I" or arg == "-E" then
        error("iron: image rendering requires Python to read PYTHONPATH (remove -I/-E)")
      end
    end
  end
  if ipython then table.insert(cmd, "--ext=iron_image") end
  local paths = vim.api.nvim_get_runtime_file("python/iron_image.py", false)
  if #paths == 0 then error("iron: bundled Python image module not found") end
  local jupyter_paths
  if jupyter then
    jupyter_paths = vim.api.nvim_get_runtime_file("python/jupyter/jupyter_config.py", false)
    if #jupyter_paths == 0 then error("iron: bundled Jupyter image config not found") end
    -- CLI values override config files. Keep options ahead of the kernel's --.
    local index = #cmd + 1
    for i, arg in ipairs(cmd) do if arg == "--" then index = i; break end end
    table.insert(cmd, index, '--ZMQTerminalInteractiveShell.mime_preference=["image/png"]')
    table.insert(cmd, index, "--ZMQTerminalInteractiveShell.image_handler=callable")
  end
  settings = type(settings) == "table" and settings or {}
  local max_images = settings.max_images or 100
  if type(max_images) ~= "number" or max_images < 1 or max_images > 1000 or max_images % 1 ~= 0 then
    error("iron: image.max_images must be an integer from 1 to 1000")
  end
  M.detach(bufnr)
  local used = {}
  for _, session in pairs(sessions) do used[session.namespace] = true end
  local namespace
  for candidate = 128, 255 do
    if not used[candidate] then namespace = candidate; break end
  end
  if not namespace then error("iron: too many image-enabled REPLs") end
  local session = { namespace = namespace, images = {}, last_id = 0, max_images = max_images }
  sessions[bufnr] = session
  local env = vim.tbl_extend("force", {}, opts.env or {})
  local pythonpath = env.PYTHONPATH or vim.env.PYTHONPATH or ""
  local separator = package.config:sub(1, 1) == "\\" and ";" or ":"
  env.PYTHONPATH = vim.fn.fnamemodify(paths[1], ":h") .. (pythonpath ~= "" and separator .. pythonpath or "")
  if jupyter then
    local configpath = env.JUPYTER_CONFIG_PATH or vim.env.JUPYTER_CONFIG_PATH or ""
    env.JUPYTER_CONFIG_PATH = vim.fn.fnamemodify(jupyter_paths[1], ":h")
      .. (configpath ~= "" and separator .. configpath or "")
    -- Kernels publish PNG MIME data; the frontend owns IDs and terminal sizing.
    env.MPLBACKEND = "module://matplotlib_inline.backend_inline"
  else
    env.MPLBACKEND = "module://iron_image_backend"
  end
  env.IRON_IMAGE_NAMESPACE = tostring(namespace)
  env.PYTHON_BASIC_REPL = env.PYTHON_BASIC_REPL or "1"
  opts.env = env
  vim.api.nvim_create_autocmd("TermRequest", {
    group = group, buffer = bufnr,
    callback = function(args)
      local sequence = args.data and args.data.sequence or ""
      if sequence:sub(1, 16) ~= esc .. "]51;iron-image;" then return end
      local ok, err = pcall(receive, session, sequence)
      if not ok then vim.notify("iron: image rendering failed: " .. tostring(err), vim.log.levels.WARN) end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group, buffer = bufnr, once = true,
    callback = function() M.detach(bufnr) end,
  })
  return cmd
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    for bufnr in pairs(sessions) do M.detach(bufnr) end
  end,
})

return M
