-- luacheck: globals unpack vim

local iron = {
  -- Will eventually be removed
  config = require("iron.config"),
  -- Most likely shouldn't be exposed here
  ll = require("iron.lowlevel"),
  core = require("iron.core"),
  setup = require("iron.core").setup
}

return iron
