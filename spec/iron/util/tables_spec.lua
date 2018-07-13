-- luacheck: globals insulate setup describe it assert mock
-- luacheck: globals before_each after_each

insulate("On #tables code", function()
  local fn = require('iron.util.tables')

  describe("#keys", function()
    it("should return only the keys of the table", function()
      local dt = {head = "z", second = "y", last = "x"}
      assert.are_same({"last", "second", "head"}, fn.keys(dt))
      end)
  end)

  describe("#values", function()
    it("should return only the keys of the table", function()
      local dt = {head = "z", second = "y", last = "x"}
      assert.are_same({"x", "y", "z"}, fn.values(dt))
      end)
  end)

  describe("#peek", function()
    it("should return the head of the table", function()
      local dt = {"a", "b", "c"}
      assert.are_same("a", fn.peek(dt))
      end)

    it("should return nil for an empty table", function()
      assert.are_same(nil, fn.peek({}))
      end)

    it("should return not change the table", function()
      local dt = {"a", "b", "c"}
      fn.peek(dt)
      assert.are_same({"a", "b", "c"}, dt)
      end)

    it("should return the first value even if a kv", function()
      local dt = {x = "val"}
      assert.are_same("val", fn.peek(dt))
      end)
  end)

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

  describe("#get_in", function()
    it("should return nil if map is nil", function()
      assert.are_same(nil, fn.get_in(nil, {"asdf"}))
      end)

    it("should return the map if the keypath lengh is 0", function()
      assert.are_same(nil, fn.get_in(nil, {}))
      assert.are_same(0, fn.get_in(0, {}))
      assert.are_same({}, fn.get_in({}, {}))
      end)

    it("should return nil if value don't exist", function()
      assert.are_same(nil, fn.get_in({}, {"asdf", "qwer"}))
      assert.are_same(nil, fn.get_in({asdf = {}}, {"asdf", "qwer"}))
      end)

    it("should return nil if nested value isn't a table", function()
      assert.are_same(nil, fn.get_in({asdf = 0}, {"asdf", "qwer"}))
      end)

    it("should return the value otherwise", function()
      assert.are_same(0, fn.get_in({asdf = 0}, {"asdf"}))
      assert.are_same(0, fn.get_in({asdf = {qwer = 0}}, {"asdf", "qwer"}))
      end)

  end)

end)

