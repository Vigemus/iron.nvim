describe("iron.util.tables.extend", function()
    local tables = require("iron.util.tables")

    it("returns an empty table when called with no arguments", function()
        assert.are.same({}, tables.extend())
    end)

    it("concatenates multiple tables", function()
        assert.are.same(
            { 1, 2, 3, 4 },
            tables.extend(
                { 1, 2 },
                { 3, 4 }
            )
        )
    end)

    it("ignores nil arguments", function()
        assert.are.same(
            { 1, 2 },
            tables.extend(
                nil,
                { 1 },
                nil,
                { 2 },
                nil
            )
        )
    end)

    it("accepts scalar values", function()
        assert.are.same(
            { "a", "b", "c" },
            tables.extend(
                "a",
                "b",
                "c"
            )
        )
    end)

    it("accepts a mixture of tables and scalar values", function()
        assert.are.same(
            { 1, 2, 3, 4, 5 },
            tables.extend(
                { 1, 2 },
                3,
                { 4 },
                5
            )
        )
    end)

    it("returns a new table", function()
        local first = { 1, 2 }
        local second = { 3, 4 }

        local result = tables.extend(first, second)

        assert.are_not.equal(result, first)
        assert.are_not.equal(result, second)
        assert.are.same({ 1, 2, 3, 4 }, result)
    end)

    it("does not modify the input tables", function()
        local first = { 1, 2 }
        local second = { 3, 4 }

        tables.extend(first, second)

        assert.are.same({ 1, 2 }, first)
        assert.are.same({ 3, 4 }, second)
    end)
end)
