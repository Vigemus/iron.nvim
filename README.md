# iron.nvim

[![CircleCI](https://circleci.com/gh/Vigemus/iron.nvim.svg?style=svg)](https://circleci.com/gh/Vigemus/iron.nvim)

Interactive Repls Over Neovim

## Support iron.nvim
Support iron.nvim development by sending me some bitcoins at `1Dnb3onNAc4XK4FL8cp7NAQ2NFspTZLNRi`.
Cheers!

## What is iron.nvim?

Iron is both a plugin and a library to allow users to deal with repls.

It keeps mechanisms to track REPLs for different file types and bindings to send data directly from the current buffer to it.

It is build on top of neovims `terminal` feature. The default terminal keybindings are kept for the terminal, meaning that to exit the insert mode, you need to use `<C-\><C-N>`.

## How to configure?

Create a lua configuration file on your `~/.config/nvim` folder (for example named `plugins.lua`) like this:

```lua
local iron = require('iron')

iron.core.add_repl_definitions{
  python = {
    mycustom = {
      command = {"mycmd"}
  },
  clojure = {
    lein_connect = {
      command = {"lein", "repl", ":connect"}
    }
  }
}

iron.core.set_config {
  preferred = {
    python = "ipython",
    clojure = "lein"
  }
}
```

And on your init.vim, simply do the following:

```vim
luafile $HOME/.config/nvim/plugins.lua
```

### Important notice!

The python remote plugin mechanism was dropped and removed from master. The latest commit containing it was [ead377f](https://github.com/Vigemus/iron.nvim/commits/ead377f).
If you wan to use that instead, please for the repository or use the stale branch [legacy](https://github.com/Vigemus/iron.nvim/commits/legacy) for that.

