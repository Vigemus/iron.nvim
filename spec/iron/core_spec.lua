-- luacheck: globals insulate setup describe it assert mock
-- luacheck: globals before_each after_each

insulate("About #iron functionality", function()
  local tbl = require('iron.util.tables')
  before_each(function()
    _G.vim = mock({
      api = {
        nvim_call_function = function(_, _) return 1 end,
        nvim_command = function(_) return "" end,
        nvim_get_option = function(_) return "" end,
        nvim_get_var = function(_) return "" end,
        nvim_create_namespace = function(_) return 1000 end,
        nvim_set_hl_ns = function(_) return nil end,
        nvim_set_hl = function(_) return nil end,
        nvim_err_writeln = function(_) return nil end,
      },
      fn = {
        executable = function(_) return true end
      }
    })

    _G.os = mock({
      execute = function(_) return 0 end,
    })
  end)

  after_each(function()
     package.loaded['iron'] = nil
     package.loaded['iron.config'] = nil
     package.loaded['iron.core'] = nil
   end)

  describe("dynamic #config", function()
    it("is not called on a stored config", function()
      local iron = require('iron')
      iron.config.stuff = 1
      local _ = iron.config.stuff
      assert.stub(_G.vim.api.nvim_get_var).was_called(0)
    end)
  end)

  describe("#core functions", function()
    it("repl_for", function()
      local iron = require('iron')
      iron.ll.ensure_repl_exists = mock(function() return {bufnr = 1}, true end)
      iron.core.repl_for("python")
      assert.spy(_G.vim.api.nvim_command).was_called(1)
    end)

    it("repl_for if repl exists", function()
      local iron = require('iron')
      iron.ll.ensure_repl_exists = mock(function() return {bufnr = 1}, true end)
      iron.config.visibility = mock(function() end)
      iron.core.repl_for("python")
      assert.spy(_G.vim.api.nvim_command).was_called(1)
      assert.spy(iron.config.visibility).was_called(0)

      iron.ll.ensure_repl_exists = mock(function() return {bufnr = 1}, false end)
      iron.core.repl_for("python")
      assert.spy(iron.config.visibility).was_called(1)

    end)
  end)
end)
