# iron.nvim

[![Sponsor me](https://img.shields.io/github/sponsors/hkupty?style=flat-square)](https://github.com/sponsors/hkupty)
[![Maintainability](https://api.codeclimate.com/v1/badges/bbd16045e0321b404ef9/maintainability)](https://codeclimate.com/github/hkupty/iron.nvim/maintainability)
[![Chat on Matrix](https://matrix.to/img/matrix-badge.svg)](https://matrix.to/#/#iron.nvim:matrix.org)

Interactive Repls Over Neovim

## What is iron.nvim

[![asciicast](https://asciinema.org/a/495376.svg)](https://asciinema.org/a/495376)
Iron allows you to quickly interact with the repl without having to leave your work buffer

It both a plugin and a library, allowing for better user experience and extensibility at the same time.

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
    },
    repl_open_cmd = require('iron.view').curry.bottom(40),
    -- how the REPL window will be opened, the default is opening
    -- a float window of height 40 at the bottom.
  },
  -- Iron doesn't set keymaps by default anymore. Set them here
  -- or use `should_map_plug = true` and map from you vim files
  keymaps = {
    send_motion = "<space>sc",
    visual_send = "<space>sc",
    send_file = "<space>sf",
    send_line = "<space>sl",
    send_mark = "<space>sm",
    mark_motion = "<space>mc",
    mark_visual = "<space>mc",
    remove_mark = "<space>md",
    cr = "<space>s<cr>",
    interrupt = "<space>s<space>",
    exit = "<space>sq",
    clear = "<space>cl",
  },
  -- If the highlight is on, you can change how it looks
  -- For the available options, check nvim_set_hl
  highlight = {
    italic = true
  }
}
```

## Support iron.nvim

Support iron.nvim development by sending me some bitcoins at `1Dnb3onNAc4XK4FL8cp7NAQ2NFspTZLNRi`.
Cheers!
