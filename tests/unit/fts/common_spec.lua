local common = require("iron.fts.common")

describe("iron.fts.common.format", function()
    it("rejects non-table input", function()
        assert.has_error(function()
            common.format({}, "hello")
        end, "Supplied lines is not a table")
    end)

    it("uses a custom formatter when one is provided", function()
        local repl = {
            command = { "python" },
            format = function(lines, extras)
                assert.are.same({ "a", "b" }, lines)
                assert.are.same({ "python" }, extras.command)
                return { "formatted" }
            end,
        }

        assert.are.same(
            { "formatted" },
            common.format(repl, { "a", "b" })
        )
    end)

    it("returns a single line unchanged except for a trailing carriage return", function()
        assert.are.same(
            { "print(1)\13" },
            common.format({}, { "print(1)" })
        )
    end)

    it("wraps multiple lines with open and close sequences", function()
        local repl = {
            open = ":paste",
            close = "\4",
        }

        assert.are.same(
            {
                ":paste",
                "a",
                "b",
                "\4\13",
            },
            common.format(repl, {
                "a",
                "b",
            })
        )
    end)

    it("returns an empty table for empty input", function()
        assert.are.same({}, common.format({}, {}))
    end)
end)

describe("iron.fts.common.bracketed_paste", function()
    it("formats a single line", function()
        assert.are.same(
            { "print(1)\13" },
            common.bracketed_paste({
                "print(1)",
            })
        )
    end)

    it("wraps multiple lines in bracketed paste markers", function()
        assert.are.same(
            {
                "\27[200~a",
                "b",
                "\27[201~\13",
            },
            common.bracketed_paste({
                "a",
                "b",
            })
        )
    end)
end)

describe("iron.fts.common.bracketed_paste_python", function()
    it("handles empty input", function()
        assert.are.same(
            { "\13" },
            common.bracketed_paste_python({}, {
                command = { "python" },
            })
        )
    end)

    it("removes blank lines", function()
        assert.are.same(
            {
                "print(1)",
                "",
            },
            common.bracketed_paste_python({
                "",
                "   ",
                "print(1)",
                "\t",
            }, {
                command = { "python" },
            })
        )
    end)

    it("adds a trailing blank line for normal python", function()
        assert.are.same(
            {
                "print(1)",
                "",
            },
            common.bracketed_paste_python({
                "print(1)",
            }, {
                command = { "python" },
            })
        )
    end)

    it("adds an extra newline when the last line is indented", function()
        assert.are.same(
            {
                "if True:",
                "    print('hello')",
                "\13",
            },
            common.bracketed_paste_python({
                "if True:",
                "    print('hello')",
            }, {
                command = { "python" },
            })
        )
    end)

    it("accepts a command function", function()
        local called = false

        common.bracketed_paste_python({
            "print(1)",
        }, {
            command = function(_)
                called = true
                return { "python" }
            end,
        })

        assert.is_true(called)
    end)

    it("formats ptpython sessions with bracketed paste markers", function()
        assert.are.same(
            {
                "\27[200~",
                "print(1)",
                "",
                "\27[201~",
                "\n",
            },
            common.bracketed_paste_python({
                "print(1)",
            }, {
                command = { "ptpython" },
            })
        )
    end)
end)
