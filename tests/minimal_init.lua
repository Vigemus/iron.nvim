vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.swapfile = false
vim.opt.hidden = true

local iron = require("iron")
local common = require("iron.fts.common")
local view = require("iron.view")

iron.setup({
  config = {
    scratch_repl = true,

    repl_open_cmd = view.split.rightbelow("%25"),

    repl_definition = {
      lua = {
        command = { "lua" },
      },
      python = {
        command = { "python3" },
        format = common.bracketed_paste_python,
        block_deviders = { "# %%", "#%%" },
        env = { PYTHON_BASIC_REPL = "1" }
      },
    },

    repl_filetype = function(_, ft)
      return ft
    end,
  },

  keymaps = {},
})
