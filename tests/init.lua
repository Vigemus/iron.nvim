vim.pack.add({
    "https://github.com/nvim-lua/plenary.nvim",
})

require("plenary.test_harness").test_directory("tests", {
    minimal_init = "tests/minimal_init.lua",
    sequential = true,
})
