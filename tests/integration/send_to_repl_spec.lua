local iron = require("tests.integration.lib.iron")

describe("integration", function()
  before_each(function()
    iron.reset()
  end)

  it("sends text to a repl", function()
    local repl = iron.create_repl("python")

    iron.send(repl, "print('hello world')")

    repl:wait_for("hello world")

    assert.is_true(repl:contains("hello world"))
  end)
end)
