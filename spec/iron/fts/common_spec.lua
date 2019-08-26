-- luacheck: globals insulate setup describe it assert mock
-- luacheck: globals before_each after_each


insulate("On fthelper", function()
  local fts = require("iron.fts.common").functions

  describe("the #format function", function()

    it("should fail on string input", function()
        assert.has.errors(function () fts.format({}, "") end)
      end)

    it("should not add a new line on #empty lines input", function()
      assert.are.same(fts.format({}, {}), {})
      end)

    it("should not add a new empty line if the last one is an #empty line", function()
      assert.are.same(fts.format({}, {"asdf", ""}), {"asdf", ""})
      end)

    it("should not add a new line if the input contains only one line", function()
      assert.are.same(fts.format({}, {"asdf"}), {"asdf"})
      end)


    it("should add a new line if the input contains more than one line", function()
      assert.are.same(fts.format({}, {"asdf", "qwer"}), {"asdf", "qwer", ""})
      end)

    it("should #wrap the lines with whatever supplied enclosing pairs", function()
      assert.are.same(
        fts.format({open = "{", close = "}"}, {"asdf", "qwer"}),
        {"{", "asdf", "qwer", "}"}
      )

      assert.are.same(
        fts.format({open = "\x1b[200~", close = "\x1b[201~"}, {"asdf", "qwer"}),
        {"\x1b[200~", "asdf", "qwer", "\x1b[201~"}
      )

      assert.are.same(
        fts.format({open = "\27[200~", close = "\27[201~"}, {"asdf", "qwer"}),
        {"\27[200~", "asdf", "qwer", "\27[201~"}
      )
      end)
  end)
end)
