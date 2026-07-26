vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.swapfile = false
vim.opt.hidden = true

local iron = require("iron")
local view = require("iron.view")

iron.setup({
    config = {
        scratch_repl = true,

        repl_open_cmd = view.split.rightbelow("%25"),

        repl_definition = {
            lua = {
                command = { "lua" },
            },
        },

        repl_filetype = function(_, ft)
            return ft
        end,
    },

    keymaps = {},
})
