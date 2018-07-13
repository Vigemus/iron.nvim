-- luacheck: globals insulate setup describe it assert mock
-- luacheck: globals before_each after_each

insulate("On #functions code", function()
  local fns = require("iron.util.functions")

  describe("#clone", function()

    it("should preserve original table", function()
      local original = {1, 2, 3}
      local cloned = fns.clone(original)
      table.insert(cloned, 4)

      assert.are_same(original, {1, 2, 3})
      assert.are_same(cloned, {1, 2, 3, 4})
      end)

    it("should create a perfect copy", function()
      local original = {1, 2, 3}
      local nested = {x = original}

      local cloned = fns.clone(original)
      local nested_cloned = fns.clone(nested)

      assert.are_same(original, cloned)
      assert.are_same(nested, nested_cloned)
      end)
    end)
end)

