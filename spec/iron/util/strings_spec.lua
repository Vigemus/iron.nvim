-- luacheck: globals insulate setup describe it assert mock
-- luacheck: globals before_each after_each

insulate("On #strings code", function()
  local strs = require("iron.util.strings")

  describe("#split", function()

    it("should preserve original string", function()
      local s = "some:thing"
      local _ = strs.split(s, ":")
      assert.are_equal(s, "some:thing")
      end)

    it("should return a table", function()
      local s = "some:thing"
      local spl = strs.split(s, ":")
      assert.are_equal("table", type(spl))
      assert.are_equal(spl[1], "some")
      assert.are_equal(spl[2], "thing")
      end)

    end)
end)
