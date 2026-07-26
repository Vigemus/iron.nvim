local iron = require("tests.integration.lib.iron")

describe("integration", function()
    before_each(function()
        iron.reset()
    end)

    it("creates a repl", function()
        local repl = iron.create_repl("python")

        assert.is_true(repl:is_alive())
        assert.equals("python", repl:filetype())
        assert.equals(2, repl:buffer())
        assert.is_true(repl:window() > 0)
        assert.same({ "python3" }, repl:command())
    end)
end)
