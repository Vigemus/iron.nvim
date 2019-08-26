-- luacheck: globals insulate setup describe it assert mock
-- luacheck: globals before_each after_each

insulate("About #iron functionality", function()
    local _ = require('iron.util.tables')
    before_each(function()
        _G.vim = mock({ api = {
                    nvim_call_function = function(_, _) return 1 end,
                    nvim_command = function(_) return "" end,
                    nvim_get_option = function(_) return "" end,
                    nvim_get_var = function(_) return "" end,
            }})

        _G.os = mock({
                execute = function(_) return 0 end,
            })
        end)

  after_each(function()
     package.loaded['iron'] = nil
     package.loaded['iron.core'] = nil
   end)

  describe("default #config", function()
    it("doesn't assume preferred values", function()
      local iron = require('iron')
      assert.are_same(iron.config.preferred.python, nil)
    end)

    it("has toggle #visibility enabled", function()
      local iron = require('iron')
      assert.are_same(iron.config.visibility, iron.behavior.visibility.toggle)
      end)
  end)

  describe("dynamic #config", function()
    it("is not called on a stored config", function()
      local iron = require('iron')
      iron.config.stuff = 1
      local _ = iron.config.stuff
      assert.stub(_G.vim.api.nvim_get_var).was_called(0)
    end)
  end)

  describe("#memory related", function()
    it("repl_for", function()
      local iron = require('iron')
      local repl = iron.core.repl_for('python')
      assert.are_same(#(_.keys(repl)), 3)
      assert.are_same(#(_.keys(iron.memory)), 1)
      assert.are_not_same(iron.memory.python, nil)
      assert.are_same(#(_.keys(iron.memory.python)), 1)
      assert.are_same(repl, iron.ll.get_from_memory('python'))
    end)
  end)

  describe("#core functions", function()
    it("repl_for", function()
      local iron = require('iron')
      iron.core.repl_for("python")
      assert.spy(_G.vim.api.nvim_command).was_called(2)
      assert.spy(_G.vim.api.nvim_call_function).was_called(3)
    end)

    it("repl_for if repl exists", function()
      local iron = require('iron')
      iron.config.visibility = mock(function() end)
      local mem1 = iron.core.repl_for("python")
      assert.spy(_G.vim.api.nvim_command).was_called(2)
      assert.spy(iron.config.visibility).was_called(0)

      local mem2 = iron.core.repl_for("python")
      assert.spy(iron.config.visibility).was_called(1)
      assert.are_same(#(_.keys(iron.memory)), 1)
      assert.are_same(mem1, mem2)

    end)
  end)
end)
