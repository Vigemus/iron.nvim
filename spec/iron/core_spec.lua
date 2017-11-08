-- luacheck: globals insulate setup describe it assert mock
-- luacheck: globals before_each after_each

insulate("About #iron functionality", function()

    local fns = require('iron.functional')
    before_each(function()
        _G.vim = mock({ api = {
                    nvim_call_function = function(_, _) return 1 end,
                    nvim_command = function(_) return nil end,
                    nvim_get_option = function(_) return "" end,
                    nvim_get_var = function(_) return "" end,
            }})

        _G.os = mock({
                execute = function(_) return 0 end,
            })
        end)

  after_each(function()
     package.loaded['iron.core'] = nil
   end)

  describe("default #config", function()
    it("doesn't assume preferred values", function()
      local iron = require('iron.core')
      assert.are_same(iron.config.preferred.python, nil)
    end)

    it("has toggle #visibility enabled", function()
      local iron = require('iron.core')
      assert.are_same(iron.config.visibility, iron.core.visibility.toggle)
      end)
  end)

  describe("dynamic #config", function()
    it("is not called on a stored config", function()
      local iron = require('iron.core')
      iron.config.stuff = 1
      local _ = iron.config.stuff
      assert.stub(_G.vim.api.nvim_get_var).was_called(0)
    end)

    it("is called on a neovim variable", function()
      local iron = require('iron.core')
      local _ = iron.config.stuff
      assert.spy(_G.vim.api.nvim_call_function).was_called(1)
      assert.spy(_G.vim.api.nvim_call_function).was.called_with("exists", {"iron_stuff"})
      assert.spy(_G.vim.api.nvim_get_var).was.called(1)
      assert.spy(_G.vim.api.nvim_get_var).was.called_with("iron_stuff")
    end)
  end)

  describe("#memory related", function()
    it("create_new_repl", function()
      local iron = require('iron.core')
      iron.core.create_new_repl("python")
      assert.are_same(#(fns.keys(iron.memory)), 1)
      assert.are_not_same(iron.memory.python, nil)
      assert.are_same(#(fns.keys(iron.memory.python)), 3)
    end)
  end)

  describe("#core functions", function()
    it("create_new_repl", function()
      local iron = require('iron.core')
      iron.core.create_new_repl("python")
      assert.spy(_G.os.execute).was_called(1)
      assert.spy(_G.os.execute).was_called_with('which ipython > /dev/null')
      assert.spy(_G.vim.api.nvim_command).was_called(1)
      assert.spy(_G.vim.api.nvim_call_function).was_called(3)
    end)
  end)
end)
