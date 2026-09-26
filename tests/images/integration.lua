-- Run from the repo root: nvim --headless -u NONE -l tests/images/integration.lua
-- Python must have matplotlib and IPython for these end-to-end checks.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.termguicolors = true
vim.opt.swapfile = false
local lowlevel = require("iron.lowlevel")
require("iron.config").close_window_on_exit = false
local sent = {}
local original_send = vim.api.nvim_chan_send
local original_ui_send = vim.api.nvim_ui_send
local esc = string.char(27)
local placeholder = vim.fn.nr2char(0x10eeee)

local function capture(sequence) sent[#sent + 1] = sequence end
local function text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end
local function wait_for(test, reason)
  assert(vim.wait(15000, test, 10), reason)
end
local function test_images(use_ui, ipython, tmux)
  sent = {}
  vim.env.TMUX = tmux and "/tmp/iron-test-tmux" or nil
  vim.env.TERM = tmux and "tmux-256color" or "xterm-ghostty"
  vim.api.nvim_ui_send = use_ui and capture or nil
  vim.api.nvim_chan_send = function(channel, sequence)
    if channel == vim.v.stderr then
      assert(not use_ui, "used stderr despite available UI API")
      capture(sequence)
    else
      original_send(channel, sequence)
    end
  end
  local buf = vim.api.nvim_create_buf(false, true)
  local command = ipython and { "python", "-m", "IPython", "--simple-prompt", "--no-autoindent" }
    or { "python", "-q" }
  local repl = { command = command, image = { max_images = 1 }, env = { IRON_TEST_KEEP = "yes" } }
  local meta = lowlevel.create_repl_on_current_window("python", repl, buf, buf)
  wait_for(function() return text(buf):find(ipython and "In %[1%]:" or ">>>") end, "REPL did not start: " .. text(buf))
  local code = "import matplotlib.pyplot as plt; plt.plot([1,2,3], [1,4,9]); plt.show(); print('PLOT_DONE')\n"
  vim.fn.chansend(meta.job, code)
  wait_for(function() return table.concat(sent):find("a=p,U=1", 1, true) end, "no placement: " .. text(buf))
  wait_for(function() return text(buf):find(placeholder, 1, true) end, "placeholder cells missing")
  assert(not text(buf):find("iron-image;", 1, true), "OSC leaked into visible REPL output")
  assert(repl.env.IRON_TEST_KEEP == "yes" and repl.env.PYTHONPATH == nil, "mutated user's environment")
  assert(#repl.command == #command, "mutated user's command")

  local graphics = {}
  for _, sequence in ipairs(sent) do
    if tmux then
      assert(sequence:sub(1, 7) == esc .. "Ptmux;")
      sequence = sequence:sub(8, -3):gsub(esc .. esc, esc)
    end
    graphics[#graphics + 1] = sequence
  end
  local payload = {}
  local image_id
  for _, sequence in ipairs(graphics) do
    local chunk = sequence:match(";(.*)" .. esc .. "\\$")
    if chunk then
      assert(#chunk <= 4096)
      payload[#payload + 1] = chunk
    end
    image_id = image_id or sequence:match("a=t,f=100,t=d,i=(%d+)")
  end
  local png = vim.base64.decode(table.concat(payload))
  assert(png:sub(1, 8) == "\137PNG\r\n\26\n", "forwarded upload is not a PNG")
  assert(#payload > 1, "test did not exercise chunked uploads")
  assert(not table.concat(sent):find("a=d", 1, true), "image deleted before buffer disposal")

  if ipython then
    vim.fn.chansend(meta.job, "from IPython.display import Image, display; import io; b=io.BytesIO(); plt.savefig(b, format='png'); display(Image(data=b.getvalue()))\n")
  else
    vim.fn.chansend(meta.job, "plt.show()\n")
  end
  wait_for(function() return table.concat(sent):find("a=d,d=I,i=" .. image_id, 1, true) end, "image limit did not evict oldest PNG")
  vim.fn.jobstop(meta.job)
  vim.fn.jobwait({meta.job}, 1000)
  local before = #sent
  vim.api.nvim_buf_delete(buf, { force = true })
  assert(#sent == before + 1 and sent[#sent]:find("a=d,d=I", 1, true), "buffer cleanup did not release PNG")
end

local function test_validation()
  sent = {}
  vim.api.nvim_ui_send = capture
  vim.env.TMUX = nil
  local buf = vim.api.nvim_create_buf(false, true)
  local opts = {}
  require("iron.image").prepare("python", { "python" }, opts, buf, true)
  local other = vim.api.nvim_create_buf(false, true)
  local other_opts = {}
  require("iron.image").prepare("python", { "python" }, other_opts, other, true)
  assert(opts.env.IRON_IMAGE_NAMESPACE ~= other_opts.env.IRON_IMAGE_NAMESPACE, "REPLs share image IDs")
  local base = tonumber(opts.env.IRON_IMAGE_NAMESPACE) * 65536
  local function emit(body)
    vim.api.nvim_exec_autocmds("TermRequest", { buffer = buf, data = { sequence = esc .. "]51;iron-image;" .. body } })
  end
  -- Unrelated OSC, a forged ID from another REPL, invalid PNG, and a missing
  -- first chunk must not result in any outer-terminal graphics command.
  vim.api.nvim_exec_autocmds("TermRequest", { buffer = buf, data = { sequence = esc .. "]7;file:///tmp" } })
  emit("1;2;2;0;0;AAAA")
  emit((base + 1) .. ";2;2;0;0;AAAA")
  emit((base + 2) .. ";2;2;1;0;AAAA")
  assert(#sent == 0, "malformed image data reached the outer terminal")
  vim.api.nvim_buf_delete(buf, { force = true })
  vim.api.nvim_buf_delete(other, { force = true })

  local failed = vim.api.nvim_create_buf(false, true)
  local ok = pcall(lowlevel.create_repl_on_current_window, "python", {
    command = { "/nonexistent/iron/python" }, image = true,
  }, failed, failed)
  assert(not ok, "invalid executable unexpectedly started")
  assert(#vim.api.nvim_get_autocmds({ group = "IronImages", buffer = failed }) == 0,
    "failed REPL startup leaked image handlers")
  vim.api.nvim_buf_delete(failed, { force = true })
end

test_images(false, false, false) -- real Neovim 0.11 stderr path
test_images(true, true, false) -- UI API path and IPython's display publisher
test_images(true, false, true) -- tmux wrapping
test_validation()
vim.api.nvim_ui_send = original_ui_send
vim.api.nvim_chan_send = original_send
print("PASS: real Python/IPython REPLs, plots, PNG display, scrollback placeholders, uploads, eviction, cleanup, tmux, validation")
