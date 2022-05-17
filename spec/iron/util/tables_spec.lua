-- luacheck: globals insulate setup describe it assert mock
-- luacheck: globals before_each after_each

insulate("On #tables code", function()
  local fn = require('iron.util.tables')

  describe("#get", function()
    it("should return nil if key doesn't exist", function()
      assert.are_same(nil, fn.get({}, "key"))
      end)

    it("should return nil if map is nil", function()
      assert.are_same(nil, fn.get(nil, "key"))
      end)

    it("should return nil if map is not a table", function()
      assert.are_same(nil, fn.get(0, "key"))
      end)

    it("should return value otherwise", function()
      assert.are_same(0, fn.get({key = 0}, "key"))
      end)
    end)

end)
