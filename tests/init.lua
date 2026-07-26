local has_pack = vim.fn.has("nvim-0.12") == 1

if has_pack then
    vim.pack.add({
        "https://github.com/nvim-lua/plenary.nvim",
    })
else
    local install_path = vim.fn.stdpath("data")
        .. "/site/pack/tests/start/plenary.nvim"

    if vim.fn.isdirectory(install_path) == 0 then
        vim.fn.system({
            "git",
            "clone",
            "--depth=1",
            "https://github.com/nvim-lua/plenary.nvim",
            install_path,
        })
    end

    vim.cmd("packloadall")
end


require("plenary.test_harness").test_directory("tests", {
    minimal_init = "tests/minimal_init.lua",
    sequential = true,
})
