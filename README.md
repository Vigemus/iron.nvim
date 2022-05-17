# iron.nvim

[![Sponsor me](https://img.shields.io/github/sponsors/hkupty?style=flat-square)](https://github.com/sponsors/hkupty)
[![Maintainability](https://api.codeclimate.com/v1/badges/bbd16045e0321b404ef9/maintainability)](https://codeclimate.com/github/hkupty/iron.nvim/maintainability)
[![Chat on Matrix](https://matrix.to/img/matrix-badge.svg)](https://matrix.to/#/#iron.nvim:matrix.org)

Interactive Repls Over Neovim

## What is iron.nvim

Iron is both a plugin and a library to allow users to deal with repls.

It keeps mechanisms to track REPLs for different file types and bindings
to send data directly from the current buffer to it.

It is build on top of neovims `terminal` feature. The default terminal
keybindings are kept for the terminal, meaning that to exit the insert mode,
you need to use `<C-\><C-N>`.

## How to configure

Below is a very simple configuration for iron:

```lua
local iron = require("iron.core")

iron.setup {
  config = {
    -- If iron should expose `<plug>(...)` mappings for the plugins
    should_map_plug = false,
    -- Whether a repl should be discarded or not
    scratch_repl = true,
    -- Your repl definitions come here
    repl_definition = {
      sh = {
        command = {"zsh"}
      }
    }
  },
  -- Iron doesn't set keymaps by default anymore. Set them here
  -- or use `should_map_plug = true` and map from you vim files
  keymaps = {
    send_motion = "<space>sc",
    visual_send = "<space>sc",
    send_line = "<space>sl",
    repeat_cmd = "<space>s.",
    cr = "<space>s<cr>",
    interrupt = "<space>s<space>",
    exit = "<space>sq",
    clear = "<space>cl",
  }
}
```

## Support iron.nvim

Support iron.nvim development by sending me some bitcoins at `1Dnb3onNAc4XK4FL8cp7NAQ2NFspTZLNRi`.
Cheers!
