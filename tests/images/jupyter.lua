-- Run from the repo root with jupyter-console, ipykernel, and matplotlib installed.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.termguicolors = true
vim.opt.swapfile = false
vim.env.TMUX = nil
vim.env.TERM = "xterm-ghostty"
local lowlevel = require("iron.lowlevel")
local common = require("iron.fts.common")
require("iron.config").close_window_on_exit = false
local sent = {}
vim.api.nvim_ui_send = function(sequence)
  sent[#sent + 1] = sequence
end
local placeholder = vim.fn.nr2char(0x10eeee)

local function text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end
local function wait_for(test, reason)
  assert(vim.wait(20000, test, 10), reason())
end

local function test_console(command, custom_config, existing)
  sent = {}
  local buf = vim.api.nvim_create_buf(false, true)
  local original = vim.deepcopy(command)
  local repl = {
    command = command,
    image = { max_images = 1 },
    format = common.bracketed_paste_python,
    env = { IRON_TEST_KEEP = "yes", JUPYTER_CONFIG_PATH = custom_config or "" },
  }
  local meta = lowlevel.create_repl_on_current_window("python", repl, buf, buf)
  wait_for(function()
    return text(buf):find("In %[1%]:")
  end, function()
    return "Jupyter did not start: " .. text(buf)
  end)
  if custom_config then
    assert(
      text(buf):find("IRON_CUSTOM_BANNER", 1, true),
      "user's Jupyter config was not loaded"
    )
  end
  if existing then
    lowlevel.send_to_repl(meta, { "%matplotlib inline" })
    wait_for(function()
      return text(buf):find("In %[2%]:")
    end, function()
      return "inline backend not ready: " .. text(buf)
    end)
  end
  lowlevel.send_to_repl(meta, {
    "import matplotlib.pyplot as plt",
    "",
    "x = 10",
    "y = 20",
    "plt.plot([1, 2, 3], [1, 4, 9])",
    "plt.show()",
    "print('CELL_RESULT', x + y, get_ipython().execution_count)",
  })
  wait_for(function()
    return table.concat(sent):find("a=p,U=1", 1, true)
  end, function()
    return "Jupyter PNG not rendered: " .. text(buf)
  end)
  wait_for(function()
    return text(buf):find(
      "CELL_RESULT 30 " .. (existing and "2" or "1"),
      1,
      true
    )
  end, function()
    return "multiline cell was not one execution: " .. text(buf)
  end)
  assert(text(buf):find(placeholder, 1, true), "no scrollback placeholders")
  assert(
    not text(buf):find("iron-image;", 1, true),
    "OSC leaked into visible output"
  )
  assert(
    vim.deep_equal(command, original) and repl.env.PYTHONPATH == nil,
    "mutated user config"
  )
  local id = table.concat(sent):match("a=t,f=100,t=d,i=(%d+)")
  lowlevel.send_to_repl(meta, {
    "import io; from IPython.display import Image, display",
    "b = io.BytesIO(); plt.savefig(b, format='png'); display(Image(data=b.getvalue()))",
    "print('PNG_DONE')",
  })
  wait_for(function()
    return table.concat(sent):find("a=d,d=I,i=" .. id, 1, true)
  end, function()
    return "PNG display did not evict the first image: " .. text(buf)
  end)
  if not existing then
    -- Direct Iron display in a local kernel must share the frontend's allocator.
    local count = #sent
    lowlevel.send_to_repl(
      meta,
      {
        "from iron_image import display as iron_display; iron_display(b.getvalue()); print('DIRECT_DONE')",
      }
    )
    wait_for(function()
      return #sent > count and text(buf):find("DIRECT_DONE", 1, true)
    end, function()
      return "direct display failed: " .. text(buf)
    end)
  end
  lowlevel.send_to_repl(meta, { "exit" })
  assert(
    vim.fn.jobwait({ meta.job }, 20000)[1] == 0,
    "console did not exit cleanly: " .. text(buf)
  )
  local before = #sent
  vim.api.nvim_buf_delete(buf, { force = true })
  assert(
    #sent == before + 1 and sent[#sent]:find("a=d,d=I", 1, true),
    "PNG cleanup failed"
  )
end

test_console({ "jupyter-console", "--no-confirm-exit" })
test_console({ "python", "-m", "jupyter_console", "--no-confirm-exit" })
test_console({ "jupyter", "console", "--no-confirm-exit" })
test_console({ "python", "-m", "jupyter", "console", "--no-confirm-exit" })

local configdir = vim.fn.tempname()
vim.fn.mkdir(configdir, "p")
vim.fn.writefile(
  {
    "c = get_config()",
    "c.ZMQTerminalInteractiveShell.banner = 'IRON_CUSTOM_BANNER'",
  },
  configdir .. "/jupyter_console_config.py"
)
test_console({ "jupyter-console", "--no-confirm-exit" }, configdir)
test_console(
  {
    "jupyter-console",
    "--no-confirm-exit",
    "--config=" .. configdir .. "/jupyter_console_config.py",
  },
  configdir
)
vim.fn.delete(configdir, "rf")

-- Start an independent kernel without Iron's environment or Python path.
local connection = vim.fn.tempname() .. ".json"
local ready = false
local owner = vim.fn.jobstart(
  {
    "python",
    "-c",
    [[
import sys
from jupyter_client import KernelManager
k = KernelManager(connection_file=sys.argv[1])
k.start_kernel()
client = k.client()
client.start_channels()
try:
    client.wait_for_ready(timeout=20)
    print('READY', flush=True)
    sys.stdin.readline()
finally:
    client.stop_channels()
    k.shutdown_kernel(now=True)
]],
    connection,
  },
  {
    on_stdout = function(_, lines)
      if table.concat(lines):find("READY", 1, true) then
        ready = true
      end
    end,
  }
)
local ok, err = pcall(function()
  wait_for(function()
    return ready
  end, function()
    return "independent kernel did not start"
  end)
  test_console(
    { "jupyter-console", "--existing=" .. connection, "--no-confirm-exit" },
    nil,
    true
  )
  assert(
    vim.fn.jobwait({ owner }, 0)[1] == -1,
    "console terminated an existing kernel"
  )
end)
vim.fn.chansend(owner, "\n")
assert(vim.fn.jobwait({ owner }, 20000)[1] == 0, "kernel cleanup failed")
assert(ok, err)
print(
  "PASS: Jupyter launch forms, multiline cells, plots, PNG display, config preservation, existing kernel, eviction, cleanup"
)
