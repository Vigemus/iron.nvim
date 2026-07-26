local iron = require("tests.integration.lib.iron")

describe("integration", function()
    before_each(function()
        iron.reset()
    end)

    it("creates a repl", function()
        local repl = iron.create_repl("lua")

        assert.is_true(repl:is_alive())
        assert.equals("lua", repl:filetype())
        assert.equals(2, repl:buffer())
        assert.is_true(repl:window() > 0)
        assert.same({ "lua" }, repl:command())
    end)
end)
